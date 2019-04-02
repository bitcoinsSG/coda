(**
 * [Parallel_scan] describes a signature of a solution for the following
 * problem statement:
 *
 * {e Efficiently compute a periodic scan on an infinite stream pumping at some
 * target rate, prefer maximizing throughput, then minimizing latency, then
 * minimizing size of state on an infinite core machine.}
 *
 * A periodic scan is a scan that only returns incremental results of some fold
 * every so often, and usually returns [None]. It requires a way to lift some
 * data ['d] into the space ['a] where an associative fold operation exists.
 *
 * The actual work of the scan is handled out-of-band, so here we expose an
 * interface of the intermediate state of some on-going long scan.
 *
 * Conceptually, you can imagine having a series of virtual trees where data
 * starts at the base and works its way up to the top, at which point we emit
 * the next incremental result. The implementation, for efficiency, does not
 * actually construct these trees, but {i succinctly} uses a ring buffer. The
 * state of the scan are these incomplete virtual trees.
 *
 * Specifically, the state of this scan is has the following primary operations:
 *
 * {!start} to create the initial state
 *
 * {!enqueue_data} adding raw data that will be lifted and processed later
 *
 * {!next_jobs} to get the next work to complete from this data
 *
 * {!fill_in_completed_jobs} moves us closer to emitting something from a tree
 *)

open Core_kernel
open Coda_digestif

(** A ring-buffer that backs our state *)
module Ring_buffer : sig
  type 'a t [@@deriving sexp, bin_io]

  val read_all : 'a t -> 'a list

  val read_k : 'a t -> int -> 'a list
end

module State : sig
  module Job : sig
    (** An incomplete job -- base may contain data ['d], merge can have zero components, one component (either the left or the right), or two components in which case there is an integer (sequence_no) representing a set of (completed)jobs in a sequence of (completed)jobs created.
     *)
    type sequence_no = int [@@deriving sexp, bin_io]

    type 'a merge =
      | Empty
      | Lcomp of 'a
      | Rcomp of 'a
      | Bcomp of ('a * 'a * sequence_no)
    [@@deriving sexp, bin_io]

    type ('a, 'd) t = Merge of 'a merge | Base of ('d * sequence_no) option
    [@@deriving sexp, bin_io]
  end

  module Completed_job : sig
    (** A completed job is either some [Lifted 'a] corresponding to some
     * [Base 'd] or a [Merged 'a] corresponding to some [Merge ('a * 'a)]
     *)
    type 'a t = Lifted of 'a | Merged of 'a [@@deriving bin_io, sexp]
  end

  (** State of the parallel scan possibly containing base ['d] entities
   * and partially complete ['a option * 'a option] merges.
   *)

  (* bin_io omitted intentionally *)
  type ('a, 'd) t [@@deriving sexp]

  module Stable :
    sig
      module V1 : sig
        type ('a, 'd) t [@@deriving sexp, bin_io]
      end

      module Latest = V1
    end
    with type ('a, 'd) V1.t = ('a, 'd) t

  (** Fold chronologically through the state. This is not the same as iterating
   * through the ring-buffer, rather we traverse the data structure in the same
   * order we expect the completed jobs to be filled in.
   *)
  val fold_chronological :
    ('a, 'd) t -> init:'acc -> f:('acc -> ('a, 'd) Job.t -> 'acc) -> 'acc

  (** Returns a list of all the collected transactions in the scan state. The
    * order of the transactions in the list is the same as the order when they
    * were added. Namely the head of the list is the first transaction that
    * was collected by the scan state.
    *)
  val transactions : ('a, 'd) t -> 'd sexp_list

  val copy : ('a, 'd) t -> ('a, 'd) t

  (** Visualize produces a tree in a way that's a bit buggy, but still was
   * helpful for debugging. [visualize state ~draw_a:(Fn.const "A") ~draw_d:(Fn.const "D")]
   * creates a tree that looks like this:
   *
                                                            (_,_)
                            (A,A)                                                           (_,_)
            (_,_)                           (A,A)                           (_,_)
      _             (_,_)           (A,A)           (_,_)
   _       _     (_,_)   (A,A)   (_,_)
 D   _   _  (_,_(A,A(_,_
D D _ _ (_(A(_
   *)
  val visualize :
    ('a, 'd) t -> draw_a:('a -> string) -> draw_d:('d -> string) -> string

  module Hash : sig
    type t = Digestif.SHA256.t
  end

  val hash : ('a, 'd) t -> ('a -> string) -> ('d -> string) -> Hash.t

  module Make_foldable (M : Monad.S) : sig
    (** Effectfully fold chronologically. See {!fold_chronological} *)
    val fold_chronological_until :
         ('a, 'd) t
      -> init:'acc
      -> f:(   'acc
            -> ('a, 'd) Job.t
            -> ('acc, 'stop) Container.Continue_or_stop.t M.t)
      -> finish:('acc -> 'stop M.t)
      -> 'stop M.t
  end
end

module Available_job : sig
  (** An available job is an incomplete job that has enough information for one
   * to process it into a completed job *)
  type sequence_no = int [@@deriving sexp]

  type ('a, 'd) t = Base of 'd * sequence_no | Merge of 'a * 'a * sequence_no
  [@@deriving sexp]
end

module Space_partition : sig
  type t = {first: int; second: int option} [@@deriving sexp]
end

module Job_view : sig
  type 'a node = Base of 'a option | Merge of 'a option * 'a option
  [@@deriving sexp]

  type 'a t = int * 'a node [@@deriving sexp]
end

(** The initial state of the parallel scan at some parallelism *)
val start : parallelism_log_2:int -> ('a, 'd) State.t

(** Get the next k available jobs *)
val next_k_jobs :
  state:('a, 'd) State.t -> k:int -> ('a, 'd) Available_job.t list Or_error.t

(** Get all the available jobs *)
val next_jobs :
  state:('a, 'd) State.t -> ('a, 'd) Available_job.t list Or_error.t

(** Get all the available jobs as a sequence *)
val next_jobs_sequence :
  state:('a, 'd) State.t -> ('a, 'd) Available_job.t Sequence.t Or_error.t

(** Add data to parallel scan state *)
val enqueue_data : state:('a, 'd) State.t -> data:'d list -> unit Or_error.t

(** Compute how much data ['d] elements we are allowed to add to the state *)
val free_space : state:('a, 'd) State.t -> int

(** Complete jobs needed at this state -- optionally emits the ['a] at the top
 * of the tree along with the ['d list] responsible for emitting the ['a]. *)
val fill_in_completed_jobs :
     state:('a, 'd) State.t
  -> completed_jobs:'a State.Completed_job.t list
  -> ('a * 'd list) option Or_error.t

(** The last ['a] we emitted from the top of the tree and the ['d list]
 * responsible for that ['a]. *)
val last_emitted_value : ('a, 'd) State.t -> ('a * 'd list) option

(** If there aren't enough slots for [max_slots] many ['d], then before
 * continuing onto the next virtual tree, split max_slots = (x,y) such that
 * x = number of slots till the end of the current tree and y = max_slots - x
 * (starts from the begining of the next tree)  *)
val partition_if_overflowing :
  max_slots:int -> ('a, 'd) State.t -> Space_partition.t

(** How much parallelism did we instantiate the state with *)
val parallelism : state:('a, 'd) State.t -> int

(** Do all the invariants of our parallel scan state hold; namely:
  * 1. The {!free_space} is equal to the number of empty leaves
  * 2. The empty leaves are in a contiguous chunk
  * 3. For all levels of the tree, if the start is empty, all is empty
  * 4. For all levels of the tree, at most one partial job is present
  * 5. All partial merge jobs are empty in the left side
  * 6. The tree is non-empty
  * 7. There exists non-zero free space (we're not deadlocked)
  *)
val is_valid : ('a, 'd) State.t -> bool

(** The data ['d] that is pending and would be returned by available [Base]
 * jobs *)
val current_data : ('a, 'd) State.t -> 'd list

val update_curr_job_seq_no : ('a, 'd) State.t -> unit Or_error.t

(*Update the current job sequence number by 1. All the completed jobs created will have the current job sequence number*)

val current_job_sequence_number : ('a, 'd) State.t -> int

(*Get the current job sequence number *)

val view_jobs_with_position :
  ('a, 'd) State.t -> ('a -> 'c) -> ('d -> 'c) -> 'c Job_view.t list

(** All the base jobs that are part of the latest tree being filled 
 * i.e., does not include base jobs that are part of previous trees not 
 * promoted to the merge jobs yet*)
val base_jobs_on_latest_tree : ('a, 'd) State.t -> 'd list
