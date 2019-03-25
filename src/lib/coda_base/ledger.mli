open Core
open Signature_lib

module Location : Merkle_ledger.Location_intf.S

module Db :
  Merkle_ledger.Database_intf.S
  with module Location = Location
  with module Addr = Location.Addr
  with type root_hash := Ledger_hash.t
   and type hash := Ledger_hash.t
   and type account := Account.t
   and type key := Public_key.Compressed.t
   and type key_set := Public_key.Compressed.Set.t

module Any_ledger :
  Merkle_ledger.Any_ledger.S
  with module Location = Location
  with type account := Account.t
   and type key := Public_key.Compressed.t
   and type key_set := Public_key.Compressed.Set.t
   and type hash := Ledger_hash.t

module Mask :
  Merkle_mask.Masking_merkle_tree_intf.S
  with module Location = Location
   and module Attached.Addr = Location.Addr
  with type account := Account.t
   and type key := Public_key.Compressed.t
   and type key_set := Public_key.Compressed.Set.t
   and type hash := Ledger_hash.t
   and type location := Location.t
   and type parent := Any_ledger.M.t

module Maskable :
  Merkle_mask.Maskable_merkle_tree_intf.S
  with module Location = Location
  with module Addr = Location.Addr
  with type account := Account.t
   and type key := Public_key.Compressed.t
   and type key_set := Public_key.Compressed.Set.t
   and type hash := Ledger_hash.t
   and type root_hash := Ledger_hash.t
   and type unattached_mask := Mask.t
   and type attached_mask := Mask.Attached.t
   and type t := Any_ledger.M.t

include
  Merkle_mask.Maskable_merkle_tree_intf.S
  with module Location := Location
  with module Addr = Location.Addr
  with type root_hash := Ledger_hash.t
   and type hash := Ledger_hash.t
   and type account := Account.t
   and type key := Public_key.Compressed.t
   and type key_set := Public_key.Compressed.Set.t
   and type t = Mask.Attached.t
   and type attached_mask = Mask.Attached.t
   and type unattached_mask = Mask.t

(* The maskable ledger is t = Mask.Attached.t because register/unregister
 * work off of this type *)
type maskable_ledger = t

(* TODO: Actually implement serializable properly #1206 *)
include
  Protocols.Coda_pow.Mask_serializable_intf
  with type serializable = int
   and type t := t
   and type unattached_mask := unattached_mask

val with_ledger : f:(t -> 'a) -> 'a

val with_ephemeral_ledger : f:(t -> 'a) -> 'a

val create : ?directory_name:string -> unit -> t

val create_ephemeral : unit -> t

val of_database : Db.t -> t

val copy : t -> t
(** This is not _really_ copy, merely a stop-gap until we remove usages of copy in our codebase. What this actually does is creates a new empty mask on top of the current ledger *)

val register_mask : t -> Mask.t -> Mask.Attached.t

val commit : Mask.Attached.t -> unit

module Undo : sig
  module User_command_undo : sig
    module Common : sig
      type t =
        { user_command: User_command.Stable.V1.t
        ; previous_receipt_chain_hash: Receipt.Chain_hash.Stable.V1.t }
      [@@deriving sexp]

      module Stable :
        sig
          module V1 : sig
            type t [@@deriving bin_io, sexp]
          end

          module Latest = V1
        end
        with type V1.t = t
    end

    module Body : sig
      type t =
        | Payment of {previous_empty_accounts: Public_key.Compressed.t list}
        | Stake_delegation of {previous_delegate: Public_key.Compressed.t}
      [@@deriving sexp]

      module Stable :
        sig
          module V1 : sig
            type t [@@deriving bin_io, sexp]
          end
        end
        with type V1.t = t
    end

    type t = {common: Common.Stable.V1.t; body: Body.Stable.V1.t}
    [@@deriving sexp]

    module Stable :
      sig
        module V1 : sig
          type t [@@deriving sexp, bin_io]
        end

        module Latest = V1
      end
      with type V1.t = t
  end

  module Fee_transfer_undo : sig
    type t =
      { fee_transfer: Fee_transfer.Stable.V1.t
      ; previous_empty_accounts: Public_key.Compressed.Stable.V1.t list }
    [@@deriving sexp]

    module Stable :
      sig
        module V1 : sig
          type t [@@deriving sexp, bin_io]
        end

        module Latest = V1
      end
      with type V1.t = t
  end

  module Coinbase_undo : sig
    type t =
      { coinbase: Coinbase.Stable.V1.t
      ; previous_empty_accounts: Public_key.Compressed.Stable.V1.t list }
    [@@deriving sexp]

    module Stable :
      sig
        module V1 : sig
          type t [@@deriving sexp, bin_io]
        end

        module Latest = V1
      end
      with type V1.t = t
  end

  module Varying : sig
    type t =
      | User_command of User_command_undo.Stable.V1.t
      | Fee_transfer of Fee_transfer_undo.Stable.V1.t
      | Coinbase of Coinbase_undo.Stable.V1.t
    [@@deriving sexp]

    module Stable :
      sig
        module V1 : sig
          type t [@@deriving sexp, bin_io]
        end

        module Latest = V1
      end
      with type V1.t = t
  end

  type t =
    {previous_hash: Ledger_hash.Stable.V1.t; varying: Varying.Stable.V1.t}
  [@@deriving sexp]

  module Stable :
    sig
      module V1 : sig
        type t [@@deriving bin_io, sexp]
      end

      module Latest = V1
    end
    with type V1.t = t

  val transaction : t -> Transaction.t Or_error.t
end

val create_new_account_exn : t -> Public_key.Compressed.t -> Account.t -> unit

val apply_user_command :
     t
  -> User_command.With_valid_signature.t
  -> Undo.User_command_undo.t Or_error.t

val apply_transaction : t -> Transaction.t -> Undo.t Or_error.t

val undo : t -> Undo.t -> unit Or_error.t

val merkle_root_after_user_command_exn :
  t -> User_command.With_valid_signature.t -> Ledger_hash.t

val create_empty : t -> Public_key.Compressed.t -> Path.t * Account.t

val num_accounts : t -> int
