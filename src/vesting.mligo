#include "../lib/fa2_interface.mligo"

type token_id = nat

type beneficiary = {
  address : address;
  amount : nat;
  claimed : nat;
}

type storage = {
  admin : address;
  start_time : option<nat>;  
  end_time : option<nat>;    
  freeze_period : nat;
  vesting_period : nat;
  beneficiaries : (address, beneficiary) map;
  token_address : address;
  token_id : token_id;
}

let start (param : unit) (s : storage) : operation list * storage =
  let caller = Tezos.sender in
  if caller <> s.admin then failwith("Unauthorized")
  else
    match s.start_time with
    | Some _ -> failwith("Vesting already started")
    | None ->
      let current_time = Tezos.now in
      let start_time = current_time + s.freeze_period in
      let end_time = start_time + s.vesting_period in
      let total_tokens = Map.fold (fun _ b acc -> acc + b.amount) s.beneficiaries 0n in
      let op = fa2_transfer s.token_address s.admin s.token_id total_tokens in
      ([op], { s with start_time = Some start_time; end_time = Some end_time })


let claim (param : unit) (s : storage) : operation list * storage =
  let caller = Tezos.sender in
  match Map.find_opt caller s.beneficiaries with
  | None -> failwith("Not a beneficiary") 
  | Some beneficiary_info ->
    match (s.start_time, s.end_time) with
    | (Some start, Some end_) when Tezos.now >= start ->
      let elapsed_time = Tezos.now - start in
      let claimable_amount =
        if elapsed_time >= s.vesting_period then
          beneficiary_info.amount - beneficiary_info.claimed
        else
          min (beneficiary_info.amount) ((beneficiary_info.amount * elapsed_time / s.vesting_period) - beneficiary_info.claimed)
      in
      let new_beneficiaries = Map.update caller (Some {beneficiary_info with claimed = beneficiary_info.claimed + claimable_amount}) s.beneficiaries in
      ([fa2_transfer s.token_address caller s.token_id claimable_amount], {s with beneficiaries = new_beneficiaries})
    | _ -> failwith("Vesting period has not started or claim not available yet")

let fa2_transfer (token_address : address) (recipient : address) (token_id : token_id) (amount : nat) : operation =
  let transfer : transfer = {
    from_ = s.admin;
    txs = [{to_ = recipient; token_id = token_id; amount = amount}]
  } in
  Tezos.transaction (Transfer [transfer]) 0mutez token_address

let update_beneficiary (param : (address * beneficiary)) (s : storage) : operation list * storage =
  let caller = Tezos.sender in
  let (beneficiary_address, new_beneficiary_data) = param in
  if caller <> s.admin then failwith("Unauthorized")
  else
    match s.start_time with
    | None ->
      let updated_beneficiaries = Map.add beneficiary_address new_beneficiary_data s.beneficiaries in
      ([], { s with beneficiaries = updated_beneficiaries })
    | Some _ -> failwith("Vesting has already started")

// fonction qui permet à l'admin de clôturer le contrat et de distribuer les fonds proportionnellement en focntion du temps écoulé
let kill (param : unit) (s : storage) : operation list * storage =
  let caller = Tezos.sender in
  if caller <> s.admin then failwith("Unauthorized")
  else
    match s.start_time with
    | Some start ->
      let current_time = Tezos.now in
      let op_list = Map.fold (fun addr b acc ->
        let elapsed_time = min (current_time - start) s.vesting_period in
        let claimable_amount = (b.amount * elapsed_time / s.vesting_period) - b.claimed in
        let transfer_op = fa2_transfer s.token_address addr s.token_id claimable_amount in
        transfer_op :: acc
      ) s.beneficiaries [] in
      (op_list, { s with beneficiaries = Map.empty })
    | None -> failwith("Vesting not started or already ended")


let main (action : fa2_entry_points) (s : storage) : operation list * storage =
  match action with
  | Start _ -> start () s
  | Claim _ -> claim () s
  | UpdateBeneficiary param -> update_beneficiary param s
  | Kill _ -> kill () s
  | _ -> failwith("Unsupported operation")