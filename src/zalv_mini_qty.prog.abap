*&---------------------------------------------------------------------*
*& Report ZALV_MINI_QTY
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT ZALV_MINI_QTY.

TABLES :  ZSD_MINI_QTY .
DATA : ITAB TYPE STANDARD TABLE OF  ZSD_MINI_QTY ,
        WA  TYPE ZSD_MINI_QTY,
       IT_FIELDCAT TYPE SLIS_T_FIELDCAT_ALV,
       WA_FIELDCAT TYPE SLIS_FIELDCAT_ALV.

SELECT-OPTIONS: PLANT    FOR ZSD_MINI_QTY-PLANT,
                STOR_LOC FOR ZSD_MINI_QTY-STOR_LOC,
                SKU      FOR ZSD_MINI_QTY-SKU,
                CRE_DATA FOR ZSD_MINI_QTY-CRE_DATA.

SELECT * FROM ZSD_MINI_QTY INTO TABLE ITAB WHERE DELETION_FLAG <> 'X'
                                             AND PLANT IN PLANT
                                             AND STOR_LOC IN STOR_LOC
                                             AND SKU IN SKU
                                             AND CRE_DATA IN CRE_DATA..
CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
 EXPORTING

    I_STRUCTURE_NAME                  = 'ZSD_MINI_QTY'
    IT_FIELDCAT                       = IT_FIELDCAT

  TABLES
    T_OUTTAB                          = ITAB
* EXCEPTIONS
*   PROGRAM_ERROR                     = 1
*   OTHERS                            = 2
          .
IF SY-SUBRC <> 0.
* Implement suitable error handling here
ENDIF.
