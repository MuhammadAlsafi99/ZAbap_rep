*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: YTRANING_T......................................*
DATA:  BEGIN OF STATUS_YTRANING_T                    .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_YTRANING_T                    .
CONTROLS: TCTRL_YTRANING_T
            TYPE TABLEVIEW USING SCREEN '0033'.
*...processing: ZCONTAINER_LOAD.................................*
DATA:  BEGIN OF STATUS_ZCONTAINER_LOAD               .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZCONTAINER_LOAD               .
CONTROLS: TCTRL_ZCONTAINER_LOAD
            TYPE TABLEVIEW USING SCREEN '0002'.
*...processing: ZDEMO_T.........................................*
DATA:  BEGIN OF STATUS_ZDEMO_T                       .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZDEMO_T                       .
CONTROLS: TCTRL_ZDEMO_T
            TYPE TABLEVIEW USING SCREEN '0200'.
*...processing: ZTABLE_TEST1....................................*
DATA:  BEGIN OF STATUS_ZTABLE_TEST1                  .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZTABLE_TEST1                  .
CONTROLS: TCTRL_ZTABLE_TEST1
            TYPE TABLEVIEW USING SCREEN '0500'.
*...processing: ZTABLE_TEST3....................................*
DATA:  BEGIN OF STATUS_ZTABLE_TEST3                  .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZTABLE_TEST3                  .
CONTROLS: TCTRL_ZTABLE_TEST3
            TYPE TABLEVIEW USING SCREEN '0330'.
*...processing: ZUSERINFO.......................................*
DATA:  BEGIN OF STATUS_ZUSERINFO                     .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZUSERINFO                     .
CONTROLS: TCTRL_ZUSERINFO
            TYPE TABLEVIEW USING SCREEN '0001'.
*.........table declarations:.................................*
TABLES: *YTRANING_T                    .
TABLES: *ZCONTAINER_LOAD               .
TABLES: *ZDEMO_T                       .
TABLES: *ZTABLE_TEST1                  .
TABLES: *ZTABLE_TEST3                  .
TABLES: *ZUSERINFO                     .
TABLES: YTRANING_T                     .
TABLES: ZCONTAINER_LOAD                .
TABLES: ZDEMO_T                        .
TABLES: ZTABLE_TEST1                   .
TABLES: ZTABLE_TEST3                   .
TABLES: ZUSERINFO                      .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
