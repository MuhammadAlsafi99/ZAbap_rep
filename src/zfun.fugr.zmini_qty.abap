
FUNCTION ZMINI_QTY.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(PLANT) TYPE  WERKS_D OPTIONAL
*"  TABLES
*"      MINIQTY_ITAB STRUCTURE  ZMINIQTY_STR OPTIONAL
*"----------------------------------------------------------------------
 SELECT PLANT STOR_LOC SKU QTY UOM  FROM ZSD_MINI_QTY INTO CORRESPONDING FIELDS OF TABLE MINIQTY_ITAB
        WHERE PLANT = PLANT AND DELETION_FLAG <> 'X' .


ENDFUNCTION.
