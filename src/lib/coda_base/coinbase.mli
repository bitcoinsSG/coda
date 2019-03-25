open Core
open Import

module Stable : sig
  module V1 : sig
    type t = private
      { proposer: Public_key.Compressed.Stable.V1.t
      ; amount: Currency.Amount.Stable.V1.t
      ; fee_transfer: Fee_transfer.Single.Stable.V1.t option }
    [@@deriving sexp, bin_io, compare, eq]
  end

  module Latest = V1
end

(* bin_io intentionally omitted in deriving list *)
type t = Stable.Latest.t = private
  { proposer: Public_key.Compressed.Stable.V1.t
  ; amount: Currency.Amount.Stable.V1.t
  ; fee_transfer: Fee_transfer.Single.Stable.V1.t option }
[@@deriving sexp, compare, eq]

val create :
     amount:Currency.Amount.t
  -> proposer:Public_key.Compressed.t
  -> fee_transfer:Fee_transfer.Single.Stable.V1.t option
  -> t Or_error.t

val supply_increase : t -> Currency.Amount.t Or_error.t

val fee_excess : t -> Currency.Fee.Signed.t Or_error.t
