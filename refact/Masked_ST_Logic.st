(*
  Project: YTEC ASRS Refactoring
  File: Masked_ST_Logic.st
  Description: ST Logic to determine Task Type based on Source/Dest Stations.
               This replaces the masked "TaskType" assignment in Lua (TTask.lua).
               Run this ST Block within the PLC scan (e.g., after Input Processing).
  Target: Mitsubishi Q Series (GX Works2/3)
*)

(* 
  Variable Mapping (Based on StackerCrane_Refactored_Q_GXW.asc BLOCK_02)
  - D330 : Task Type (Output derived by this ST)
           100 = Inbound (Storage)
           200 = Outbound (Retrieval)
           300 = Transfer (Move)
  - D339 : Source Station ID (Input from TTask.lua -> D3009 -> D339)
  - D340 : Destination Station ID (Input from TTask.lua -> D3010 -> D340)

  Note: 
  - In TTask.lua (Refact), 'srm.TaskType' is masked (not sent).
  - TTask.lua sends 'WriteSrcStation' (maps to D339) and 'WriteDestStation' (maps to D340).
  - Inbound Task: SrcStation is set (e.g., 1001, 1002), DestStation is 0 (dest is Rack).
  - Outbound Task: DestStation is set (e.g., 1001, 1003), SrcStation is 0 (src is Rack).
*)

// ST Program Start
IF (D339 > 0) AND (D340 = 0) THEN
    D330 := 100; // Inbound (Storage) Task
ELSIF (D339 = 0) AND (D340 > 0) THEN
    D330 := 200; // Outbound (Retrieval) Task
ELSIF (D339 > 0) AND (D340 > 0) THEN
    D330 := 300; // Transfer Task (Station to Station)
ELSE
    // Optional: Reset D330 if no valid command signals are present
    // D330 := 0; 
END_IF;
