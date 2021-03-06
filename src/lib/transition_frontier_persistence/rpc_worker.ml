open Core
open Async
open Coda_base

module Make (Inputs : Intf.Worker_inputs) = struct
  open Inputs

  module type S = sig
    val handle_diff :
      Diff_hash.t -> State_hash.t Diff_mutant.E.t -> Diff_hash.t
  end

  module Worker = Worker.Make (Inputs)

  module Worker_state = struct
    type t = (module S)

    type init_arg = string [@@deriving bin_io]

    let create directory_name : t Deferred.t =
      let logger = Logger.create () in
      let worker = Worker.create ~logger ~directory_name () in
      let module M = struct
        let handle_diff = Worker.handle_diff worker
      end in
      Deferred.return (module M : S)
  end

  module Functions = struct
    type ('i, 'o) t =
      'i Bin_prot.Type_class.t
      * 'o Bin_prot.Type_class.t
      * (Worker_state.t -> 'i -> 'o Deferred.t)

    let create input output f : ('i, 'o) t = (input, output, f)

    let handle_diff =
      create
        [%bin_type_class:
          Diff_hash.t * State_hash.Stable.Latest.t Diff_mutant.E.t]
        Diff_hash.bin_t (fun (module W) (diff_hash, diff_mutant) ->
          Deferred.return (W.handle_diff diff_hash diff_mutant) )
  end

  module Rpc_worker = struct
    module T = struct
      module F = Rpc_parallel.Function

      type 'w functions =
        { handle_diff:
            ( 'w
            , Diff_hash.t * State_hash.Stable.Latest.t Diff_mutant.E.t
            , Diff_hash.t )
            F.t }

      module Worker_state = Worker_state

      module Connection_state = struct
        type init_arg = unit [@@deriving bin_io]

        type t = unit
      end

      module Functions
          (C : Rpc_parallel.Creator
               with type worker_state := Worker_state.t
                and type connection_state := Connection_state.t) =
      struct
        let functions =
          let f (i, o, f) =
            C.create_rpc
              ~f:(fun ~worker_state ~conn_state:_ i -> f worker_state i)
              ~bin_input:i ~bin_output:o ()
          in
          let open Functions in
          {handle_diff= f handle_diff}

        let init_worker_state = Worker_state.create

        let init_connection_state ~connection:_ ~worker_state:_ = return
      end
    end

    include Rpc_parallel.Make (T)
  end

  type t = {connection: Rpc_worker.Connection.t; process: Process.t}

  let create ~directory_name =
    let%map connection, process =
      Rpc_worker.spawn_in_foreground_exn
        ~connection_timeout:(Time.Span.of_min 1.) ~on_failure:Error.raise
        ~shutdown_on:Disconnect ~connection_state_init_arg:() directory_name
    in
    File_system.dup_stdout process ;
    File_system.dup_stderr process ;
    {connection; process}

  let handle_diff {connection; _} hash diff =
    Rpc_worker.Connection.run connection ~f:Rpc_worker.functions.handle_diff
      ~arg:(hash, diff)
end
