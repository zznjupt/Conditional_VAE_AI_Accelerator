debImport "-sv" "-f" "rtl.f"
debLoadSimResult /home/ICer/work/GRU_AI_Accelerator/applicaction/tb.fsdb
wvCreateWindow
schCreateWindow -delim "." -win $_nSchema1 -scope "CVAE_tb"
schSetOptions -win $_nSchema3 -pan on
schZoomIn -win $_nSchema3 -pos 20779 5574
schZoomIn -win $_nSchema3 -pos 20747 5163
schZoomIn -win $_nSchema3 -pos 20747 5163
schZoomIn -win $_nSchema3 -pos 20747 5163
schZoomOut -win $_nSchema3 -pos 20574 5017
schZoomOut -win $_nSchema3 -pos 20557 4983
schZoomOut -win $_nSchema3 -pos 20557 4962
schZoomOut -win $_nSchema3 -pos 20557 4962
schZoomOut -win $_nSchema3 -pos 20557 4961
schZoomIn -win $_nSchema3 -pos 31838 700
verdiSetFont -font "Bitstream Vera Sans" -size "20"
verdiSetFont -monoFont "Courier" -monoFontSize "18"
schSelect -win $_nSchema3 -inst "cvae"
schSelect -win $_nSchema3 -inst "cvae"
schPushViewIn -win $_nSchema3
schSelect -win $_nSchema3 -inst "gru"
schSelect -win $_nSchema3 -inst "gru"
schSelect -win $_nSchema3 -inst "gru"
schPushViewIn -win $_nSchema3
schZoomOut -win $_nSchema3 -pos 27374 3409
schZoomOut -win $_nSchema3 -pos 27374 3409
schZoomIn -win $_nSchema3 -pos 22545 6742
schZoomIn -win $_nSchema3 -pos 22545 6742
debExit
