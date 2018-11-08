vlib work
vlib riviera

vlib riviera/xil_defaultlib
vlib riviera/xpm
vlib riviera/gtwizard_ultrascale_v1_7_4

vmap xil_defaultlib riviera/xil_defaultlib
vmap xpm riviera/xpm
vmap gtwizard_ultrascale_v1_7_4 riviera/gtwizard_ultrascale_v1_7_4

vlog -work xil_defaultlib  -sv2k12 "+incdir+../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source" "+incdir+../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source" \
"C:/Xilinx/Vivado/2018.2/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
"C:/Xilinx/Vivado/2018.2/data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv" \
"C:/Xilinx/Vivado/2018.2/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \

vcom -work xpm -93 \
"C:/Xilinx/Vivado/2018.2/data/ip/xpm/xpm_VCOMP.vhd" \

vlog -work gtwizard_ultrascale_v1_7_4  -v2k5 "+incdir+../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source" "+incdir+../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source" \
"../../../ipstatic/hdl/gtwizard_ultrascale_v1_7_bit_sync.v" \
"../../../ipstatic/hdl/gtwizard_ultrascale_v1_7_gte4_drp_arb.v" \
"../../../ipstatic/hdl/gtwizard_ultrascale_v1_7_gthe4_delay_powergood.v" \
"../../../ipstatic/hdl/gtwizard_ultrascale_v1_7_gtye4_delay_powergood.v" \
"../../../ipstatic/hdl/gtwizard_ultrascale_v1_7_gthe3_cpll_cal.v" \
"../../../ipstatic/hdl/gtwizard_ultrascale_v1_7_gthe3_cal_freqcnt.v" \
"../../../ipstatic/hdl/gtwizard_ultrascale_v1_7_gthe4_cpll_cal.v" \
"../../../ipstatic/hdl/gtwizard_ultrascale_v1_7_gthe4_cpll_cal_rx.v" \
"../../../ipstatic/hdl/gtwizard_ultrascale_v1_7_gthe4_cpll_cal_tx.v" \
"../../../ipstatic/hdl/gtwizard_ultrascale_v1_7_gthe4_cal_freqcnt.v" \
"../../../ipstatic/hdl/gtwizard_ultrascale_v1_7_gtye4_cpll_cal.v" \
"../../../ipstatic/hdl/gtwizard_ultrascale_v1_7_gtye4_cpll_cal_rx.v" \
"../../../ipstatic/hdl/gtwizard_ultrascale_v1_7_gtye4_cpll_cal_tx.v" \
"../../../ipstatic/hdl/gtwizard_ultrascale_v1_7_gtye4_cal_freqcnt.v" \
"../../../ipstatic/hdl/gtwizard_ultrascale_v1_7_gtwiz_buffbypass_rx.v" \
"../../../ipstatic/hdl/gtwizard_ultrascale_v1_7_gtwiz_buffbypass_tx.v" \
"../../../ipstatic/hdl/gtwizard_ultrascale_v1_7_gtwiz_reset.v" \
"../../../ipstatic/hdl/gtwizard_ultrascale_v1_7_gtwiz_userclk_rx.v" \
"../../../ipstatic/hdl/gtwizard_ultrascale_v1_7_gtwiz_userclk_tx.v" \
"../../../ipstatic/hdl/gtwizard_ultrascale_v1_7_gtwiz_userdata_rx.v" \
"../../../ipstatic/hdl/gtwizard_ultrascale_v1_7_gtwiz_userdata_tx.v" \
"../../../ipstatic/hdl/gtwizard_ultrascale_v1_7_reset_sync.v" \
"../../../ipstatic/hdl/gtwizard_ultrascale_v1_7_reset_inv_sync.v" \

vlog -work xil_defaultlib  -v2k5 "+incdir+../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source" "+incdir+../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/ip_0/sim/gtwizard_ultrascale_v1_7_gtye4_channel.v" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/ip_0/sim/pcie4_uscale_plus_0_gt_gtye4_channel_wrapper.v" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/ip_0/sim/pcie4_uscale_plus_0_gt_gtwizard_gtye4.v" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/ip_0/sim/pcie4_uscale_plus_0_gt_gtwizard_top.v" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/ip_0/sim/pcie4_uscale_plus_0_gt.v" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source/pcie4_uscale_plus_0_gtwizard_top.v" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source/pcie4_uscale_plus_0_phy_ff_chain.v" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source/pcie4_uscale_plus_0_phy_pipeline.v" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source/pcie4_uscale_plus_0_bram_16k_int.v" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source/pcie4_uscale_plus_0_bram_16k.v" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source/pcie4_uscale_plus_0_bram_32k.v" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source/pcie4_uscale_plus_0_bram_4k_int.v" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source/pcie4_uscale_plus_0_bram_msix.v" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source/pcie4_uscale_plus_0_bram_rep_int.v" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source/pcie4_uscale_plus_0_bram_rep.v" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source/pcie4_uscale_plus_0_bram_tph.v" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source/pcie4_uscale_plus_0_bram.v" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source/pcie4_uscale_plus_0_gt_gt_channel.v" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source/pcie4_uscale_plus_0_gt_gt_common.v" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source/pcie4_uscale_plus_0_gt_phy_clk.v" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source/pcie4_uscale_plus_0_gt_phy_rst.v" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source/pcie4_uscale_plus_0_gt_phy_rxeq.v" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source/pcie4_uscale_plus_0_gt_phy_txeq.v" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source/pcie4_uscale_plus_0_sync_cell.v" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source/pcie4_uscale_plus_0_sync.v" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source/pcie4_uscale_plus_0_gt_cdr_ctrl_on_eidle.v" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source/pcie4_uscale_plus_0_gt_receiver_detect_rxterm.v" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source/pcie4_uscale_plus_0_gt_phy_wrapper.v" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source/pcie4_uscale_plus_0_init_ctrl.v" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source/pcie4_uscale_plus_0_pl_eq.v" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source/pcie4_uscale_plus_0_vf_decode.v" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source/pcie4_uscale_plus_0_pipe.v" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source/pcie4_uscale_plus_0_phy_top.v" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source/pcie4_uscale_plus_0_seqnum_fifo.v" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source/pcie4_uscale_plus_0_sys_clk_gen_ps.v" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/source/pcie4_uscale_plus_0_pcie4_uscale_core_top.v" \
"../../../../pcie4_uscale_plus_0_ex.srcs/sources_1/ip/pcie4_uscale_plus_0/sim/pcie4_uscale_plus_0.v" \

vlog -work xil_defaultlib \
"glbl.v"

