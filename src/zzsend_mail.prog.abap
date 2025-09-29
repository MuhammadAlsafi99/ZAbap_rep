*&---------------------------------------------------------------------*
*& Report ZZSEND_MAIL
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT ZZSEND_MAIL.


TABLES : ZUSERS.

TYPES : BEGIN OF TAB1,
        BNAME TYPE USR02-BNAME,
        MAIL TYPE ADR6-SMTP_ADDR,
        NAME_TEXTC TYPE USER_ADDR-NAME_TEXTC,
        BANFN TYPE EBAN-BANFN,
        END OF TAB1.
DATA : USERS TYPE STANDARD TABLE OF TAB1,
       USERS_MAIL TYPE STANDARD TABLE OF TAB1,
       WA_U LIKE LINE OF USERS,
       WA_M LIKE LINE OF USERS.
DATA : ZREL_GROUP_TAB TYPE TABLE OF ZREL_GROUP_TAB,
       WA_REL LIKE LINE OF  ZREL_GROUP_TAB,
       REQUISITION_ITEMS  TYPE TABLE OF BAPIEBANC,
       WA_PR LIKE LINE OF REQUISITION_ITEMS .

SELECT-OPTIONS : USER for ZUSERS-BNAME." NO-DISPLAY.
PERFORM GET_USER_PR.
PERFORM SEND_MAIL.
write ' '.
FORM GET_USER_PR.
"GET USERS MAIL
SELECT U~BNAME D~SMTP_ADDR AS MAIL UD~NAME_TEXTC
FROM ZUSERS AS U  INNER JOIN USR21 ON U~BNAME = USR21~BNAME
INNER JOIN ADR6 AS D ON D~ADDRNUMBER = USR21~ADDRNUMBER AND D~PERSNUMBER = USR21~PERSNUMBER
INNER JOIN USER_ADDR AS UD ON UD~BNAME = U~BNAME
INTO CORRESPONDING FIELDS OF TABLE USERS
WHERE U~BNAME IN USER.

LOOP AT USERS INTO WA_U.
REFRESH ZREL_GROUP_TAB.
CALL FUNCTION 'ZGET_USER_AUTH_FOR_OBJ'
  EXPORTING
    X_CLIENT             = SY-MANDT
    X_UNAME              = WA_U-BNAME
    X_OBJECT             = 'M_EINK_FRG'
   SPRAS                = 'E'
* IMPORTING
*   E_TEXT               =
  TABLES
    ZREL_GROUP_TAB       = ZREL_GROUP_TAB .
DELETE ZREL_GROUP_TAB WHERE FRGOT = 2.
LOOP AT ZREL_GROUP_TAB INTO WA_REL.
  REFRESH REQUISITION_ITEMS.
  CALL FUNCTION 'BAPI_REQUISITION_GETITEMSREL'
    EXPORTING
      REL_GROUP               = WA_REL-FRGGR
      REL_CODE                = WA_REL-FRGCO
     ITEMS_FOR_RELEASE       = 'X'
    TABLES
      REQUISITION_ITEMS       = REQUISITION_ITEMS
*     RETURN                  =
.
  LOOP AT REQUISITION_ITEMS INTO WA_PR.
     WA_M-BNAME = WA_U-BNAME .
     WA_M-MAIL = WA_U-MAIL.
     WA_M-NAME_TEXTC = WA_U-NAME_TEXTC.
     WA_M-BANFN = WA_PR-PREQ_NO.
     APPEND WA_M TO USERS_MAIL.
     CLEAR : WA_M , WA_PR.
  ENDLOOP.
CLEAR : WA_REL.
ENDLOOP.
CLEAR : WA_U.
ENDLOOP.
ENDFORM.
FORM SEND_MAIL.
 CLASS cl_bcs DEFINITION LOAD.
   DATA : message TYPE  bcsy_text,
         DEAR TYPE STRING.
   DATA:
   lo_send_request TYPE REF TO cl_bcs VALUE IS INITIAL,
   year type char4,
   month type char10,
   month_num TYPE char2,
   strtxt TYPE char100,
   i_subject TYPE SO_OBJ_DES.
   lo_send_request = cl_bcs=>create_persistent( ).
* Message body and subject
   DATA:
   lt_message_body TYPE  bcsy_text VALUE IS INITIAL ,
   lo_document TYPE REF TO cl_document_bcs VALUE IS INITIAL.
DATA : PRS TYPE STRING.
"Subject
   CLEAR i_subject.
    i_subject = 'Purchase Requisition'.
CLEAR : WA_U,WA_M,message.

LOOP AT USERS INTO WA_U.
  refresh :message.
  LOOP AT USERS_MAIL INTO WA_M WHERE BNAME = WA_U-BNAME.
*    IF PRS IS INITIAL.
*      PRS = wa_m-BANFN.
*    ELSE.
*    CONCATENATE PRS wa_m-BANFN INTO PRS SEPARATED BY CL_ABAP_CHAR_UTILITIES=>NEWLINE.
*    ENDIF.
    APPEND WA_M-BANFN TO MESSAGE.
    CLEAR : WA_M.
  ENDLOOP.
  if message is not INITIAL.
  "Body
  CONCATENATE 'Dear' WA_U-NAME_TEXTC ',' INTO DEAR SEPARATED BY space.
  APPEND DEAR TO lt_message_body.
*   APPEND 'Dear,' TO lt_message_body.
   append ' ' to lt_message_body.
   append 'Kindly note that the following purchase requisitions need to be released' TO lt_message_body.
   append ' ' to lt_message_body.
*   append PRS to lt_message_body.
   APPEND LINES OF MESSAGE TO lt_message_body.
   append ' ' to lt_message_body.
   APPEND 'Best Regards' TO lt_message_body.
   append ' ' to lt_message_body.
   APPEND 'Automated mail generated from SAP system.' TO lt_message_body.

   "Create Document
   lo_document = cl_document_bcs=>create_document(
   i_type = 'RAW'
   i_text = lt_message_body
   i_subject = i_subject ).
   DATA: lx_document_bcs TYPE REF TO cx_document_bcs VALUE IS INITIAL.

* Add attachment
* Pass the document to send request
   lo_send_request->set_document( lo_document ).

*  * Create sender
   DATA:
   lo_sender TYPE REF TO if_sender_bcs VALUE IS INITIAL,
   l_send type ADR6-SMTP_ADDR.
*  lo_sender = cl_cam_address_bcs=>create_internet_address( l_send ).
   lo_sender = cl_sapuser_bcs=>create( sy-uname ).
* Set sender
   lo_send_request->set_sender(
   EXPORTING
   i_sender = lo_sender ).


*    Create recipient
   DATA:
   lo_recipient TYPE REF TO if_recipient_bcs VALUE IS INITIAL,
   reciever type ADR6-SMTP_ADDR.

   reciever = WA_U-MAIL.
*  lo_recipient = cl_sapuser_bcs=>create( sy-uname ).

IF sy-subrc = 0 and reciever is not INITIAL and lo_sender is not INITIAL.
*  DATA REC TYPE SY-UNAME.
*   REC = WA_U-BNAME.
   lo_recipient = cl_cam_address_bcs=>create_internet_address( reciever ).
   lo_send_request->add_recipient(
   EXPORTING
   i_recipient = lo_recipient
   i_express = 'X' ).
ENDIF.

*  * Send email
   DATA: lv_sent_to_all(1) TYPE c VALUE IS INITIAL.
   lo_send_request->send(
   EXPORTING
   i_with_error_screen = 'X'
   RECEIVING
   result = lv_sent_to_all ).
   COMMIT WORK.


clear : MESSAGE, lt_message_body,DEAR .
clear i_subject.

   CLEAR : PRS , WA_U.
   ENDIF.
  ENDLOOP.
ENDFORM.
