open Core
open Async

module Inputs = struct
  module Worker_state = struct
    include Unit

    let create () = Deferred.unit

    let worker_wait_time = 0.1
  end

  module Proof = struct
    (* TODO : version *)
    type t =
      Transaction_snark.Statement.Stable.V1.t
      * Coda_base.Sok_message.Digest.Stable.V1.t
    [@@deriving bin_io, sexp]
  end

  module Statement = Transaction_snark.Statement

  module Public_key = struct
    include Signature_lib.Public_key.Compressed

    let arg_type = Cli_lib.Arg_type.public_key_compressed
  end

  module Transaction = Coda_base.Transaction
  module Sparse_ledger = Coda_base.Sparse_ledger
  module Pending_coinbase = Coda_base.Pending_coinbase
  module Transaction_witness = Coda_base.Transaction_witness

  let perform_single () ~message s =
    Ok
      ( ( Snark_work_lib.Work.Single.Spec.statement s
        , Coda_base.Sok_message.digest message )
      , Time.Span.zero )
end

module Worker = Worker.Make (Inputs)
