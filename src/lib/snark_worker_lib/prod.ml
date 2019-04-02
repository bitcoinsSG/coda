open Core
open Async
open Signature_lib

module Cache = struct
  module T = Hash_heap.Make (Transaction_snark.Statement)

  type t = (Time.t * Transaction_snark.t) T.t

  let max_size = 100

  let create () : t = T.create (fun (t1, _) (t2, _) -> Time.compare t1 t2)

  let add t ~statement ~proof =
    T.push_exn t ~key:statement ~data:(Time.now (), proof) ;
    if Int.( > ) (T.length t) max_size then ignore (T.pop_exn t)

  let find (t : t) statement = Option.map ~f:snd (T.find t statement)
end

module Inputs = struct
  module Worker_state = struct
    module type S = Transaction_snark.S

    type t = {m: (module S); cache: Cache.t}

    let create () =
      let%map proving = Snark_keys.transaction_proving ()
      and verification = Snark_keys.transaction_verification () in
      { m=
          ( module Transaction_snark.Make (struct
            let keys = {Transaction_snark.Keys.proving; verification}
          end)
          : S )
      ; cache= Cache.create () }

    let worker_wait_time = 5.
  end

  module Proof = Transaction_snark.Stable.V1
  module Statement = Transaction_snark.Statement

  module Public_key = struct
    include Public_key.Compressed

    let arg_type = Cli_lib.Arg_type.public_key_compressed
  end

  module Transaction = Coda_base.Transaction
  module Sparse_ledger = Coda_base.Sparse_ledger
  module Pending_coinbase = Coda_base.Pending_coinbase
  module Transaction_witness = Coda_base.Transaction_witness

  (* TODO: Use public_key once SoK is implemented *)
  let perform_single ({m= (module M); cache} : Worker_state.t) ~message =
    let open Snark_work_lib in
    let sok_digest = Coda_base.Sok_message.digest message in
    fun single ->
      let statement = Work.Single.Spec.statement single in
      match Cache.find cache statement with
      | Some proof -> Or_error.return (proof, Time.Span.zero)
      | None -> (
        match single with
        | Work.Single.Spec.Transition (input, t, (w : Transaction_witness.t))
          ->
            let start = Time.now () in
            let res =
              M.of_transaction ~sok_digest ~source:input.Statement.source
                ~target:input.target t
                ~pending_coinbase_stack_state:
                  input.Statement.pending_coinbase_stack_state
                (unstage (Coda_base.Sparse_ledger.handler w.ledger))
            in
            Cache.add cache ~statement ~proof:res ;
            let total = Time.abs_diff (Time.now ()) start in
            Or_error.return (res, total)
        | Merge (_, proof1, proof2) ->
            let open Or_error.Let_syntax in
            let start = Time.now () in
            let%map res = M.merge ~sok_digest proof1 proof2 in
            Cache.add cache ~statement ~proof:res ;
            let total = Time.abs_diff (Time.now ()) start in
            (res, total) )
end

module Worker = Worker.Make (Inputs)
