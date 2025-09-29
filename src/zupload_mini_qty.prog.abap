*&---------------------------------------------------------------------*
*& Report ZUPLOAD_MINI_QTY
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT ZUPLOAD_MINI_QTY.

TABLES: ZSD_MINI_QTY.

PARAMETERS: P_FILE TYPE RLGRAP-FILENAME OBLIGATORY.



DATA: IT_EXCEL        TYPE TABLE OF ALSMEX_TABLINE,
      WA_EXCEL        TYPE ALSMEX_TABLINE,
      ITAB            TYPE STANDARD TABLE OF ZSD_MINI_QTY,
      WA              TYPE ZSD_MINI_QTY,
      LV_EXISTS       TYPE ABAP_BOOL,
      LV_MESSAGE      TYPE STRING.


AT SELECTION-SCREEN ON VALUE-REQUEST FOR P_FILE.
  " FILE SELECTION DIALOG
  CALL FUNCTION 'F4_FILENAME'
    IMPORTING
      FILE_NAME = P_FILE.

START-OF-SELECTION.

  " STEP 1: READ EXCEL DATA
  CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
    EXPORTING
      FILENAME                = P_FILE
      I_BEGIN_COL             = 1
      I_BEGIN_ROW             = 2
      I_END_COL               = 10
      I_END_ROW               = 1000
    TABLES
      INTERN                  = IT_EXCEL
    EXCEPTIONS
      INCONSISTENT_PARAMETERS = 1
      UPLOAD_OLE              = 2
      OTHERS                  = 3.

  IF SY-SUBRC <> 0.
    WRITE: / 'ERROR UPLOADING EXCEL FILE.'.
    EXIT.
  ENDIF.

  " STEP 2: MAP EXCEL DATA TO Z TABLE

  LOOP AT IT_EXCEL INTO WA_EXCEL.
    CASE WA_EXCEL-COL.
      WHEN 1. WA-PLANT    = WA_EXCEL-VALUE.
      WHEN 2. WA-STOR_LOC = WA_EXCEL-VALUE.
      WHEN 3. WA-SKU      = WA_EXCEL-VALUE.
      WHEN 4. WA-QTY      = WA_EXCEL-VALUE.
      WHEN 5. WA-UOM      = WA_EXCEL-VALUE.
    ENDCASE.
    IF WA_EXCEL-COL = 5.
         APPEND WA TO ITAB.
         CLEAR  WA.
    ENDIF.

  ENDLOOP.

  PERFORM VALIDATION.
*  PERFORM INSERT_DATA_TO_ZTABLE.
*&---------------------------------------------------------------------*
*& Form VALIDATION
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM VALIDATION .
 DATA : MSG        TYPE STRING,
        MSG1       TYPE STRING,
        MSGID      TYPE i,
        NUM_RANGE  TYPE NROBJ.


***************CALL FUNCTION 'NUMBER_GET_NEXT'
***************  EXPORTING
***************    NR_RANGE_NR                   = '01'
***************    OBJECT                        = 'ZMINIQTY_N'
****************   QUANTITY                      = '1'
****************   SUBOBJECT                     = ' '
****************   TOYEAR                        = '0000'
****************   IGNORE_BUFFER                 = ' '
***************  IMPORTING
***************   NUMBER                         = NUM_RANGE
****************   QUANTITY                      =
****************   RETURNCODE                    =
**************** EXCEPTIONS
****************   INTERVAL_NOT_FOUND            = 1
****************   NUMBER_RANGE_NOT_INTERN       = 2
****************   OBJECT_NOT_FOUND              = 3
****************   QUANTITY_IS_0                 = 4
****************   QUANTITY_IS_NOT_1             = 5
****************   INTERVAL_OVERFLOW             = 6
****************   BUFFER_OVERFLOW               = 7
****************   OTHERS                        = 8
***************          .
***************IF SY-SUBRC <> 0.
**************** Implement suitable error handling here
***************ENDIF.
***************



  LOOP AT ITAB INTO WA.
      CALL FUNCTION 'NUMBER_GET_NEXT'
                    EXPORTING
                      NR_RANGE_NR             = '01'
                      OBJECT                  = 'ZMINIQTY_N'
                    IMPORTING
                      NUMBER                  =  NUM_RANGE
                    EXCEPTIONS
                      INTERVAL_NOT_FOUND      = 1
                      NUMBER_RANGE_NOT_INTERN = 2
                      OBJECT_NOT_FOUND        = 3
                      QUANTITY_IS_0           = 4
                      QUANTITY_IS_NOT_1       = 5
                      INTERVAL_OVERFLOW       = 6
                      BUFFER_OVERFLOW         = 7
                      OTHERS                  = 8.

     IF SY-SUBRC <> 0 .
                MESSAGE 'ERROR IN NUMBER_RANGE' TYPE 'E'.
     ENDIF.
      WA-NUM_RANGE = NUM_RANGE .


"""""""Validate in storage location & material"""""""""
     IF WA-UOM <> 'OUT'.
         MESSAGE 'Error in unit of measure !' TYPE 'E'.
     ENDIF.
    SELECT SINGLE LGORT  FROM MARD INTO @DATA(TEMP) WHERE WERKS = @WA-PLANT.
    IF SY-SUBRC <> 0.
            MSG = | Storage Location { wa-STOR_LOC } Doesn't Exist In The Plant { wa-plant } |.
        MESSAGE MSG TYPE 'E'.
        EXIT.
    ELSE.
       SELECT SINGLE  MATNR  FROM MARD INTO @DATA(TEMP_M) WHERE WERKS = @WA-PLANT AND LGORT = @WA-STOR_LOC AND MATNR = @WA-SKU.
        IF SY-SUBRC <> 0.
            MSG = | Material { wa-sku } Doesn't Exist In Storage Location { wa-stor_loc }|.
        MESSAGE MSG TYPE 'E'.
        EXIT.
        ENDIF.
    ENDIF.
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

"""""""Validate storage location & material in ztable""""

     SELECT SINGLE PLANT , STOR_LOC ,  SKU , QTY FROM ZSD_MINI_QTY INTO @DATA(TEMP2) WHERE PLANT = @WA-PLANT
                                                                                       AND STOR_LOC = @WA-STOR_LOC
                                                                                       AND SKU = @WA-SKU
                                                                                       AND QTY = @WA-QTY
                                                                                       AND DELETION_FLAG <> 'X'.
      IF SY-SUBRC EQ 0.
                MSG1 = | Material { wa-sku } Already Exist In Storage Location { wa-stor_loc } With QTY { wa-qty } |.
                MESSAGE MSG1 TYPE 'E'.
                EXIT.



      ELSEIF SY-SUBRC <> 0.
       SELECT SINGLE * FROM ZSD_MINI_QTY INTO @DATA(ZTEMP) WHERE PLANT = @WA-PLANT AND STOR_LOC = @WA-STOR_LOC AND SKU = @WA-SKU.
         IF SY-SUBRC EQ 0.
            UPDATE ZSD_MINI_QTY  SET
             DEL_TIME      = SY-TIMLO
             DEL_DATE      = SY-DATUM
             DUSER         = SY-UNAME
             DELETION_FLAG = 'X'
             WHERE PLANT   = ZTEMP-PLANT AND STOR_LOC = ZTEMP-STOR_LOC AND SKU = ZTEMP-SKU  AND QTY = ZTEMP-QTY.
            WA-CRE_DATA      = SY-DATUM.
            WA-CRE_TIME      = SY-TIMLO.
            WA-USER_NAME     = SY-UNAME.
            INSERT ZSD_MINI_QTY FROM WA.
              MSGID = 1.
         ELSE.
            WA-CRE_DATA      = SY-DATUM.
            WA-CRE_TIME      = SY-TIMLO.
            WA-USER_NAME     = SY-UNAME.
*           SKU           = WA-SKU .
*           QTY           = WA-QTY.
*           DEL_TIME      = SY-TIMLO
*           DEL_DATE      = SY-DATUM
*           DUSER         = SY-UNAME
*           DELETION_FLAG = 'X'
            INSERT ZSD_MINI_QTY FROM WA.


             MSGID = 2.
         endif.


       ENDIF.

  ENDLOOP.

   IF MSGID = 2.
   MESSAGE 'Excel File Has Been Uploaded Successfully!' TYPE 'I'.
    EXIT.
   ELSEIF MSGID = 1.
   MESSAGE |Excel File Has Been Uploaded Successfully With Updates !| TYPE 'I'.
    EXIT.
   ENDIF.

ENDFORM.
