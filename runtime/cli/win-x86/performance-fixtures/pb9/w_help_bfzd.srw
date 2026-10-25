$PBExportHeader$w_help_bfzd.srw
forward
global type w_help_bfzd from w_common_select_m
end type
end forward

global type w_help_bfzd from w_common_select_m
integer width = 2373
integer height = 1784
string title = "Ñ¡Ôñ°õ·¿"
end type
global w_help_bfzd w_help_bfzd

on w_help_bfzd.create
call super::create
end on

on w_help_bfzd.destroy
call super::destroy
end on

event ue_init_controls;call super::ue_init_controls;dw_master.retrieve()

return 1
end event

event ue_enter;call super::ue_enter;long ll_row
string ls_dwdm

ll_row = dw_master.getrow()
if ll_row <= 0 then return

ls_dwdm = dw_master.getitemstring(ll_row,'grbfzd_bfbh')

closewithreturn(this,ls_dwdm)

end event

type cb_cancel from w_common_select_m`cb_cancel within w_help_bfzd
integer x = 1687
integer y = 1504
integer height = 112
end type

type cb_enter from w_common_select_m`cb_enter within w_help_bfzd
integer x = 1179
integer y = 1504
integer height = 112
end type

type dw_master from w_common_select_m`dw_master within w_help_bfzd
integer x = 14
integer y = 16
integer width = 2327
integer height = 1396
string dataobject = "d_help_bfzd"
end type

type st_filter from w_common_select_m`st_filter within w_help_bfzd
integer y = 1536
end type

type sle_filter from w_common_select_m`sle_filter within w_help_bfzd
integer y = 1520
end type

