open Core_kernel

module type Inputs_intf = sig
  module Ledger_hash : sig
    type t
  end

  module Ledger_proof_statement : sig
    type t [@@deriving compare, sexp]
  end

  module Sparse_ledger : sig
    type t
  end

  module Transaction : sig
    type t
  end

  module Transaction_witness : sig
    type t
  end

  module Ledger_proof : sig
    type t
  end

  module Fee : sig
    type t [@@deriving compare]
  end

  module Transaction_snark_work : sig
    type t

    val fee : t -> Fee.t
  end

  module Snark_pool : sig
    type t

    val get_completed_work :
      t -> Ledger_proof_statement.t list -> Transaction_snark_work.t option
  end

  module Staged_ledger : sig
    type t

    val all_work_pairs_exn :
         t
      -> ( ( Ledger_proof_statement.t
           , Transaction.t
           , Transaction_witness.t
           , Ledger_proof.t )
           Snark_work_lib.Work.Single.Spec.t
         * ( Ledger_proof_statement.t
           , Transaction.t
           , Transaction_witness.t
           , Ledger_proof.t )
           Snark_work_lib.Work.Single.Spec.t
           option )
         list
  end
end

module Test_input = struct
  module Transaction_witness = Int
  module Ledger_hash = Int
  module Ledger_proof_statement = Int
  module Sparse_ledger = Int
  module Transaction = Int
  module Ledger_proof = Int
  module Fee = Int

  module Transaction_snark_work = struct
    type t = Int.t

    let fee = Fn.id
  end

  module Snark_pool = struct
    module T = struct
      type t = Ledger_proof.t list [@@deriving bin_io, hash, compare, sexp]
    end

    module Work = Hashable.Make_binable (T)

    type t = Transaction_snark_work.t Work.Table.t

    let get_completed_work (t : t) = Work.Table.find t

    let create () = Work.Table.create ()

    let add_snark t ~work ~fee = Work.Table.add_exn t ~key:work ~data:fee
  end

  module Staged_ledger = struct
    type t = int List.t

    let work i = Snark_work_lib.Work.Single.Spec.Transition (i, i, i)

    let chunks_of xs ~n = List.groupi xs ~break:(fun i _ _ -> i mod n = 0)

    let paired ls =
      let pairs = chunks_of ls ~n:2 in
      List.map pairs ~f:(fun js ->
          match js with
          | [j] -> (work j, None)
          | [j1; j2] -> (work j1, Some (work j2))
          | _ -> failwith "error pairing jobs" )

    let all_work_pairs_exn (t : t) = paired t
  end
end
