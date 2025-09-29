FUNCTION ZYSP_VS_UPLOAD_T2.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(ROUTEID) TYPE  KUNNR OPTIONAL
*"     VALUE(SALESREP) TYPE  KUNNR OPTIONAL
*"     VALUE(REG_NO) TYPE  CHAR10 OPTIONAL
*"     VALUE(HISTDATE) TYPE  DATUM OPTIONAL
*"  EXPORTING
*"     VALUE(STATUS) TYPE  NUM2
*"     VALUE(HISTDATEO) TYPE  DATUM
*"  TABLES
*"      HH_HEADER STRUCTURE  YSP_VS_HH_H
*"      HH_DETAILS STRUCTURE  YSP_VS_HH_D
*"      HH_DETAILS_DIS STRUCTURE  YSP_VS_HH_D_DIS
*"      VISITS_LIST STRUCTURE  YSP_VS_MOB_VIST
*"      ORDER_STATUS STRUCTURE  YSP_VS_ORDER_H
*"      VISITS_STATUS STRUCTURE  YSP_VS_MOB_VIST_CUST
*"      VISITSTEPS STRUCTURE  YSP_VS_MOB_VSTEP
*"      ANSWERS STRUCTURE  YSP_VS_ANSWERS
*"      PERSONALVALUE STRUCTURE  YSP_VS_PER_VALUE
*"      ATTACHEMENTANSWER STRUCTURE  YSP_VS_ATT_ANS
*"      ANSWERVALUE STRUCTURE  YSP_VS_ANS_VALUE
*"      CHOICEVALUEANSWER STRUCTURE  YSP_VS_CHO_VALUE
*"      DRIVERCOORDENATE STRUCTURE  YSP_VS_COORD
*"      ORDER_TKMK STRUCTURE  YSP_VS_ORDER_TKMK_UPLOAD
*"      EXPENSE STRUCTURE  YSP_VS_EXPENSE
*"      SHIP_H STRUCTURE  YSP_VS_SHIP_H OPTIONAL
*"      SHIP_UP STRUCTURE  YSP_VS_SHIP_UP OPTIONAL
*"      EINV_UP STRUCTURE  YSP_VS_EINV_UP_S OPTIONAL
*"      EINV_PICS STRUCTURE  YSP_VS_EINV_PICS OPTIONAL
*"      PROMO_A STRUCTURE  YSP_VS_PROMO_A OPTIONAL
*"----------------------------------------------------------------------

  DATA: WA_REP_REG TYPE YSP_VS_SR_REG.
  DATA: WA_YSP_VS_SALESREP TYPE YSP_VS_SALESREP.

  DATA: WA_HH_HEADER LIKE LINE OF HH_HEADER,
        WA_MOB_VIS_H TYPE YSP_VS_MOB_VIS_H,
        VISITID      TYPE STRING,
        WA_PAYMENT   TYPE YSP_VS_PAYMENT,
        WA_EXPENSE   TYPE YSP_VS_EXPENSE.

  DATA: LOG    TYPE STANDARD TABLE OF YSP_VS_LOG,
        WA_LOG LIKE LINE OF LOG.

  DATA: TYPE_OUT TYPE KSCHL.

  DATA: INV_STATUS TYPE NUM2.

  DATA: WA_ONETIME TYPE YSP_VS_ONETIME.
  DATA: WA_PROMO_ONE TYPE YSP_VS_PROMO_ONE,
        WA_PROMO_A   TYPE YSP_VS_PROMO_A.

  TRY.
      UNPACK REG_NO TO REG_NO.
      UNPACK SALESREP TO SALESREP.
    CATCH CX_SY_CONVERSION_NO_NUMBER.
  ENDTRY.

  STATUS = 0.
  DATA: WA_VISITS_LIST   TYPE  YSP_VS_MOB_VIST,
        WA_VISITS_STATUS LIKE LINE OF VISITS_STATUS.

  DATA: WA_LOCK TYPE YSP_VS_LOCK.

  DATA: COND_RECORD TYPE KNUMH,
        ONE_TIME    LIKE YSP_VS_COND_SETT-ONE_TIME.

  "LOCK SALESREP TABLE
  CALL FUNCTION 'ENQUEUE_EYSP_VS_LOCK'
    EXPORTING
      MODE_YSP_VS_LOCK = 'E'
      MANDT            = SY-MANDT
      SALESREP         = SALESREP
*     X_SALESREP       = ' '
*     _SCOPE           = '2'
*     _WAIT            = ' '
*     _COLLECT         = ' '
    EXCEPTIONS
      FOREIGN_LOCK     = 1
      SYSTEM_FAILURE   = 2
      OTHERS           = 3.

  IF SY-SUBRC EQ 0.
    SELECT SINGLE * FROM YSP_VS_LOCK
      INTO WA_LOCK
      WHERE SALESREP = SALESREP.

    IF SY-SUBRC NE 0 OR WA_LOCK-FLAG = 'U'. "UNLOCKED OR NOT FOUND
      WA_LOCK-SALESREP = SALESREP.
      WA_LOCK-FLAG = 'L'.
      MODIFY YSP_VS_LOCK FROM WA_LOCK.
      COMMIT WORK AND WAIT.


*GET SALES REP FROM REG
      SELECT SINGLE * FROM YSP_VS_SR_REG AS S
        INNER JOIN YSP_VS_ROUTE_REP AS R
        ON R~ROUTE = S~SALESREP
        INTO CORRESPONDING FIELDS OF WA_REP_REG
        WHERE S~SALESREP = ROUTEID AND S~REG_NO = REG_NO AND
       R~ROUTE = ROUTEID AND R~SALESREP = SALESREP.
      IF SY-SUBRC <> 0.
        STATUS = 1.
      ELSE.
*    AND ( status = 'A' OR status = 'P' )
        IF WA_REP_REG-STATUS = 'R'.
          STATUS = 3.
        ELSEIF WA_REP_REG-STATUS = 'D' OR WA_REP_REG-STATUS = 'L'.
          STATUS = 4.
        ELSE.

*      "$. Region VISIT LIST
          IF VISITS_LIST[] IS NOT INITIAL.
            LOOP AT VISITS_LIST INTO WA_VISITS_LIST.
              IF WA_VISITS_LIST-ROUTE_ID IS INITIAL.
                WA_VISITS_LIST-ROUTE_ID = ROUTEID.
              ENDIF.
              MODIFY YSP_VS_MOB_VIST FROM WA_VISITS_LIST.
              WA_VISITS_STATUS-ASEQ_ID = WA_VISITS_LIST-ASEQ_ID.
              WA_VISITS_STATUS-VISIT_ID = WA_VISITS_LIST-VISIT_ID.

              DELETE FROM YSP_VS_MOB_VSTEP WHERE ASEQ_ID = WA_VISITS_LIST-ASEQ_ID AND VISIT_ID = WA_VISITS_LIST-VISIT_ID.
              LOOP AT VISITSTEPS WHERE VISIT_ID = WA_VISITS_LIST-VISIT_ID AND ASEQ_ID = WA_VISITS_LIST-ASEQ_ID.
                MODIFY YSP_VS_MOB_VSTEP FROM VISITSTEPS.
              ENDLOOP.
              APPEND WA_VISITS_STATUS TO VISITS_STATUS.
            ENDLOOP.
          ENDIF.

*      "$. Endregion VISIT LIST

          CLEAR: WA_MOB_VIS_H, VISITID.

*          SELECT SINGLE VISIT_ID FROM YSP_VS_MOB_VIST
*            INTO VISITID
*            WHERE PARNR = SALESREP AND EXTFLD2 = SY-DATUM.

          SELECT SINGLE * FROM YSP_VS_MOB_VIS_H
            INTO CORRESPONDING FIELDS OF WA_MOB_VIS_H
            WHERE ROUTE_ID = ROUTEID AND START_DATE = SY-DATUM
            AND VISIT_STATUS NE 'C'.

          IF SY-SUBRC EQ 0.
            WA_MOB_VIS_H-DOWNLOAD_STATUS = 'D'.
            MODIFY YSP_VS_MOB_VIS_H FROM WA_MOB_VIS_H.
          ENDIF.

*      "$. Region SURVEY UPLOAD

          DATA: SERIAL TYPE NUM4.
*      SERIAL = 1.
          LOOP AT ANSWERS.
            MODIFY YSP_VS_ANSWERS FROM ANSWERS.
          ENDLOOP.
*      SERIAL = 1.
          LOOP AT PERSONALVALUE.
*        PERSONALVALUE-SERIAL = SERIAL.
*        SERIAL = SERIAL + 1.
            MODIFY  YSP_VS_PER_VALUE FROM PERSONALVALUE .
          ENDLOOP.
*      SERIAL = 1.
          LOOP AT ATTACHEMENTANSWER.
*        ATTACHEMENTANSWER-SERIAL = SERIAL.
*        SERIAL = SERIAL + 1.
            MODIFY YSP_VS_ATT_ANS FROM ATTACHEMENTANSWER.
          ENDLOOP.
*      SERIAL = 1.
*        ANSWERVALUE-SERIAL = SERIAL.
*        SERIAL = SERIAL + 1.
          ""ADDED NEW 8.12.2020
          DATA: ANS_WA LIKE LINE OF ANSWERS.
          LOOP AT ANSWERVALUE.
            LOOP AT ANSWERS INTO ANS_WA WHERE SURVEYID = ANSWERVALUE-SURVEYID
              AND ANSWERID = ANSWERVALUE-ANSWERID.
              ANSWERVALUE-TIMESTAMP = ANS_WA-TIMESTAMP.
            ENDLOOP.
            ""ADDED NEW 8.12.2020
            MODIFY YSP_VS_ANS_VALUE FROM ANSWERVALUE.
          ENDLOOP.
*      SERIAL = 1.
          LOOP AT CHOICEVALUEANSWER.
*        CHOICEVALUEANSWER-SERIAL = SERIAL.
*        SERIAL = SERIAL + 1.
            MODIFY YSP_VS_CHO_VALUE FROM CHOICEVALUEANSWER.
          ENDLOOP.
*      "$. Endregion SURVEY UPLOAD

          DATA: CUST_NUM     TYPE KUNNR,
                WA_RP_DEBGEO TYPE /DSD/RP_DEBGEO,
                CUST_TMS     TYPE C LENGTH 14.

          LOOP AT DRIVERCOORDENATE.
*        CHOICEVALUEANSWER-SERIAL = SERIAL.
*        SERIAL = SERIAL + 1.
            MODIFY YSP_VS_COORD FROM DRIVERCOORDENATE.
            IF DRIVERCOORDENATE-TYPE = '9'.
              CLEAR: CUST_NUM.
              SELECT SINGLE CUST_NO FROM YSP_VS_MOB_VIST
                INTO CUST_NUM WHERE VISIT_ID = DRIVERCOORDENATE-VISIT_ID
                AND ASEQ_ID = DRIVERCOORDENATE-ASEQ_ID.
              IF SY-SUBRC EQ 0.
                CLEAR: WA_RP_DEBGEO, CUST_TMS.
                SELECT SINGLE * FROM /DSD/RP_DEBGEO
                  INTO CORRESPONDING FIELDS OF WA_RP_DEBGEO
                  WHERE KUNNR = CUST_NUM.
                IF SY-SUBRC EQ 0.
                  WA_RP_DEBGEO-LONGITUDE = DRIVERCOORDENATE-DRIVER_LON.
                  WA_RP_DEBGEO-LATITUDE = DRIVERCOORDENATE-DRIVER_LAT.
                  WA_RP_DEBGEO-AEDAT = SY-DATUM.
                  WA_RP_DEBGEO-AEZET = SY-UZEIT.
                  WA_RP_DEBGEO-AENAM = SY-UNAME.
                  MODIFY /DSD/RP_DEBGEO FROM WA_RP_DEBGEO.
                  CONCATENATE SY-DATUM SY-UZEIT INTO CUST_TMS.
                  UPDATE YSP_VS_CUSTOMER SET CUST_LOT = WA_RP_DEBGEO-LATITUDE
                  CUST_LON = WA_RP_DEBGEO-LONGITUDE TMS = CUST_TMS WHERE CUST_NO = CUST_NUM.
                  CLEAR: WA_RP_DEBGEO.
                ELSE.
                  WA_RP_DEBGEO-KUNNR = CUST_NUM.
                  WA_RP_DEBGEO-LONGITUDE = DRIVERCOORDENATE-DRIVER_LON.
                  WA_RP_DEBGEO-LATITUDE = DRIVERCOORDENATE-DRIVER_LAT.
                  WA_RP_DEBGEO-AEDAT = SY-DATUM.
                  WA_RP_DEBGEO-AEZET = SY-UZEIT.
                  WA_RP_DEBGEO-AENAM = SY-UNAME.
                  INSERT /DSD/RP_DEBGEO FROM WA_RP_DEBGEO.
                  CONCATENATE SY-DATUM SY-UZEIT INTO CUST_TMS.
                  UPDATE YSP_VS_CUSTOMER SET CUST_LOT = WA_RP_DEBGEO-LATITUDE
                  CUST_LON = WA_RP_DEBGEO-LONGITUDE TMS = CUST_TMS  WHERE CUST_NO = CUST_NUM.
                  CLEAR: WA_RP_DEBGEO.
                ENDIF.
              ENDIF.
            ENDIF.

          ENDLOOP.

          LOOP AT ORDER_TKMK.
*            UPDATE YSP_VS_OR_TKMK SET STATUS = ORDER_TKMK-STATUS INVOICENO = ORDER_TKMK-INVOICENO
*            WHERE ORDERNO = ORDER_TKMK-ORDERNO.
            UPDATE YSP_VS_EORDER SET STATUS = ORDER_TKMK-STATUS HH_ORDER = ORDER_TKMK-INVOICENO
            VISIT_ID = ORDER_TKMK-VISIT_ID ASEQ = ORDER_TKMK-ASEQ SEQ = ORDER_TKMK-SEQ ROUTE = ROUTEID
            WHERE ORDERNO = ORDER_TKMK-ORDERNO.
          ENDLOOP.

          """NEW ADDED LOG TABLE
          DATA: EORDER_WA LIKE LINE OF ORDER_TKMK,
                EORDER_L  TYPE YSP_VS_EORDER_L.

          LOOP AT ORDER_TKMK INTO EORDER_WA.

*            DELETE FROM YSP_VS_EORDER_L WHERE ORDERNO = EORDER_WA-ORDERNO.

            CLEAR: EORDER_L.
            EORDER_L-ORDERNO = EORDER_WA-ORDERNO.
            CONCATENATE SY-DATUM SY-UZEIT INTO EORDER_L-TMS.
            EORDER_L-STATUS = EORDER_WA-STATUS.
            EORDER_L-HH_ORDER = EORDER_WA-INVOICENO.
            EORDER_L-VISIT_ID = EORDER_WA-VISIT_ID.
            EORDER_L-ASEQ = EORDER_WA-ASEQ.
            EORDER_L-SEQ = EORDER_WA-SEQ.

            INSERT YSP_VS_EORDER_L FROM EORDER_L.
          ENDLOOP.

          DATA: OBJNR LIKE IHPA-OBJNR,
                EQUNR LIKE EQUI-EQUNR.
          CLEAR: OBJNR, EQUNR.

          TRY.
              UNPACK SALESREP TO SALESREP.
            CATCH CX_SY_CONVERSION_NO_NUMBER..
          ENDTRY.

          SELECT SINGLE OBJNR FROM IHPA INTO OBJNR
            WHERE OBTYP = 'IEQ' AND PARNR = SALESREP.

          IF SY-SUBRC EQ 0.
            SELECT SINGLE EQUNR FROM EQUI INTO EQUNR
              WHERE OBJNR = OBJNR.
          ENDIF.

          LOOP AT EXPENSE INTO WA_EXPENSE.
*        CHOICEVALUEANSWER-SERIAL = SERIAL.
*        SERIAL = SERIAL + 1.
            WA_EXPENSE-VEHICLEID = EQUNR.
            INSERT YSP_VS_EXPENSE  FROM WA_EXPENSE.
            "MODIFY YSP_VS_EXPENSE FROM EXPENSE.
          ENDLOOP.
          "HEADER / DETAILS

          IF HH_HEADER[] IS NOT INITIAL.

            LOOP AT HH_HEADER.
              DELETE FROM YSP_VS_LOG WHERE ORDERTYPE = HH_HEADER-ORDERTYPE
                AND ORDERNO = HH_HEADER-ORDERNO.
              "CHECK IF EXISTS
              SELECT SINGLE * FROM YSP_VS_HH_H
                INTO CORRESPONDING FIELDS OF WA_HH_HEADER
                WHERE ORDERTYPE = HH_HEADER-ORDERTYPE
                AND ORDERNO = HH_HEADER-ORDERNO.

              IF SY-SUBRC NE 0. "NOT FOUND
                DELETE FROM YSP_VS_HH_D WHERE ORDERTYPE = HH_HEADER-ORDERTYPE
                AND ORDERNO = HH_HEADER-ORDERNO.

                DELETE FROM YSP_VS_HH_D_DIS WHERE ORDERTYPE = HH_HEADER-ORDERTYPE
                AND ORDERNO = HH_HEADER-ORDERNO.

                COMMIT WORK AND WAIT.

                LOOP AT HH_DETAILS WHERE ORDERTYPE = HH_HEADER-ORDERTYPE
                    AND ORDERNO = HH_HEADER-ORDERNO.
                  INSERT YSP_VS_HH_D FROM HH_DETAILS.
                ENDLOOP.

                LOOP AT HH_DETAILS_DIS WHERE ORDERTYPE = HH_HEADER-ORDERTYPE
                    AND ORDERNO = HH_HEADER-ORDERNO.
                  SELECT SINGLE DESCRIPTION FROM YSP_VS_PROMASTER
                    INTO HH_DETAILS_DIS-PROMOTIONDESC
                    WHERE PROMOTIONID = HH_DETAILS_DIS-PROMOTIONID.
                  "SELECT CONDITION OUT
                  CLEAR: TYPE_OUT, ONE_TIME.

                  """ADDED NEW 26.8.20
                  DATA: TEMP TYPE P DECIMALS 2.
                  CLEAR: TEMP.
                  IF HH_DETAILS_DIS-COND_TYPE = 'ZEOE'.
                    CASE HH_DETAILS_DIS-PROMOTIONID.
                      WHEN '1'. "" SAME COND --- YEOR
                        HH_DETAILS_DIS-COND_TYPE = 'YEOR'.
                      WHEN '2'. "" DIVIDE TO 2ND & 3RD COND --- Y2OR Y3OR
                        HH_DETAILS_DIS-CALC_TYPE = 'B'. """""ADDED NEW 30.08.2020
                        HH_DETAILS_DIS-PROMOTIONDESC = HH_DETAILS_DIS-DISCOUNT.
                        TEMP = HH_DETAILS_DIS-DISCOUNT / 2.
                        HH_DETAILS_DIS-DISCOUNT = HH_DETAILS_DIS-DISCOUNT - TEMP.
                        HH_DETAILS_DIS-COND_TYPE = 'Y2OR'.
*                        HH_DETAILS_DIS-AMT_PRCNT = HH_DETAILS_DIS-AMT_PRCNT / 2.
                        HH_DETAILS_DIS-AMT_PRCNT = HH_DETAILS_DIS-DISCOUNT. """""ADDED NEW 30.08.2020
                      WHEN '3'. "" ADD TO 2ND COND --- Y2OR
                        HH_DETAILS_DIS-CALC_TYPE = 'B'. """""ADDED NEW 30.08.2020
                        HH_DETAILS_DIS-COND_TYPE = 'Y2OR'.
                        HH_DETAILS_DIS-AMT_PRCNT = HH_DETAILS_DIS-DISCOUNT. """""ADDED NEW 30.08.2020
                      WHEN OTHERS. "" SAME COND --- YEOR
                        HH_DETAILS_DIS-COND_TYPE = 'YEOR'.
                    ENDCASE.
                    """ADDED NEW 26.8.20
                  ELSE.
                    SELECT SINGLE TYPE_OUT ONE_TIME FROM YSP_VS_COND_SETT
                      INTO (TYPE_OUT,ONE_TIME) WHERE TYPE_IN = HH_DETAILS_DIS-COND_TYPE.
                  ENDIF.

                  IF SY-SUBRC EQ 0 AND TYPE_OUT NE HH_DETAILS_DIS-COND_TYPE
                    AND TYPE_OUT IS NOT INITIAL.
                    HH_DETAILS_DIS-COND_TYPE = TYPE_OUT.
                  ENDIF.

                  "CHECK DUPLICATE ONETIME DISCOUNTS
                  IF ONE_TIME EQ 'X'.
                    CLEAR: COND_RECORD.
                    SELECT SINGLE COND_RECORD FROM YSP_VS_HH_D_DIS
                      INTO COND_RECORD
                      WHERE COND_RECORD = HH_DETAILS_DIS-COND_RECORD
                      AND ORDERTYPE NE HH_HEADER-ORDERTYPE AND ORDERNO NE HH_HEADER-ORDERNO.

                    IF COND_RECORD IS NOT INITIAL.
                      HH_HEADER-STATUS = 'E'.

                      CLEAR: WA_LOG.
                      CALL FUNCTION 'NUMBER_GET_NEXT'
                        EXPORTING
                          NR_RANGE_NR = '01'
                          OBJECT      = 'YSP_VS_LOG'
                        IMPORTING
                          NUMBER      = WA_LOG-SERIAL.

                      WA_LOG-ORDERTYPE = HH_HEADER-ORDERTYPE.
                      WA_LOG-ORDERNO = HH_HEADER-ORDERNO.
                      WA_LOG-TYPE = 'E'.
                      WA_LOG-MSGNUMBER = 906.
                      CONCATENATE 'Condition Record' HH_DETAILS_DIS-COND_RECORD 'is duplicated' INTO WA_LOG-MESSAGE
                      SEPARATED BY SPACE.
                      WA_LOG-MSGDATE = SY-DATUM.
                      WA_LOG-MSGTIME = SY-UZEIT.
                      INSERT YSP_VS_LOG FROM WA_LOG.
                    ENDIF.
                  ENDIF.

                  INSERT YSP_VS_HH_D_DIS FROM HH_DETAILS_DIS.

                  """ADDED NEW 26.8.20
                  IF HH_DETAILS_DIS-COND_TYPE = 'Y2OR' AND HH_DETAILS_DIS-PROMOTIONID = '2'.
                    HH_DETAILS_DIS-DISSERIAL = HH_DETAILS_DIS-DISSERIAL + 4.
                    HH_DETAILS_DIS-DISCOUNT = TEMP.
                    HH_DETAILS_DIS-AMT_PRCNT = HH_DETAILS_DIS-DISCOUNT. """""ADDED NEW 30.08.2020
                    HH_DETAILS_DIS-COND_TYPE = 'Y3OR'.
                    INSERT YSP_VS_HH_D_DIS FROM HH_DETAILS_DIS.
                  ENDIF.
                  """ADDED NEW 26.8.20

                  "UPDATE ONETIME CONDITIONS
                  CLEAR: WA_ONETIME.
                  SELECT SINGLE * FROM YSP_VS_ONETIME
                    INTO CORRESPONDING FIELDS OF WA_ONETIME
                    WHERE COND_RECORD = HH_DETAILS_DIS-COND_RECORD
                    AND ROUTE_ID = ROUTEID.

                  IF SY-SUBRC EQ 0.
                    UPDATE (WA_ONETIME-TABLE_NO) SET KBSTAT = '20'
                     WHERE KNUMH = WA_ONETIME-COND_RECORD AND KAPPL = 'V'
                     AND KSCHL = WA_ONETIME-COND_TYPE.
                    DELETE FROM YSP_VS_ONETIME WHERE COND_RECORD = WA_ONETIME-COND_RECORD AND ROUTE_ID = ROUTEID.
                  ENDIF.

                  "UPDATE BONUS BUY
                  CLEAR: WA_PROMO_ONE.
                  SELECT SINGLE * FROM YSP_VS_PROMO_ONE
                    INTO CORRESPONDING FIELDS OF WA_PROMO_ONE
                    WHERE PROMOID = HH_DETAILS_DIS-COND_RECORD
                    AND ROUTE_ID = ROUTEID AND CUST_NO = HH_HEADER-CUSTOMERNO.

                  IF SY-SUBRC EQ 0.
                    CLEAR: WA_PROMO_A.
                    SELECT SINGLE * FROM YSP_VS_PROMO_A
                      INTO CORRESPONDING FIELDS OF WA_PROMO_A
                      WHERE CUST_NO = HH_HEADER-CUSTOMERNO
                      AND PROMOID = HH_DETAILS_DIS-COND_RECORD.

                    WA_PROMO_A-CURR_USED = WA_PROMO_A-CURR_USED + 1.

                    IF WA_PROMO_A-CURR_USED EQ WA_PROMO_A-NO_OF_TIMES.
                      UPDATE YSP_VS_PROMO_A SET STATUS = '20' CURR_USED = WA_PROMO_A-CURR_USED
                      WHERE CUST_NO = HH_HEADER-CUSTOMERNO
                      AND PROMOID = HH_DETAILS_DIS-COND_RECORD.
                    ELSE.
                      UPDATE YSP_VS_PROMO_A SET CURR_USED = WA_PROMO_A-CURR_USED
                      WHERE CUST_NO = HH_HEADER-CUSTOMERNO
                      AND PROMOID = HH_DETAILS_DIS-COND_RECORD.
                    ENDIF.
                  ENDIF.

                ENDLOOP.

                SELECT SINGLE PLANT FROM YSP_VS_SALESREP INTO HH_HEADER-BRANCHNO
                  WHERE SALESREP = SALESREP.
                HH_HEADER-ROUTE_ID = ROUTEID.
                IF HH_HEADER-ORDERTYPE = '9'.
                  HH_HEADER-VISIT_ID = WA_MOB_VIS_H-VISIT_ID.
                ENDIF.

                ""PAYMENTS
                IF HH_HEADER-ORDERTYPE = '2' OR HH_HEADER-ORDERTYPE = '3' OR HH_HEADER-ORDERTYPE = '4' OR HH_HEADER-ORDERTYPE = '5'.
                  "INSERT ACCOUNTING DOCUMENT
                  CLEAR: WA_PAYMENT.
                  SELECT SINGLE * FROM YSP_VS_PAYMENT
                    INTO WA_PAYMENT WHERE SBORDERNO = HH_HEADER-ORDERNO
                    AND ORDERTYPE = HH_HEADER-ORDERTYPE.
                  IF SY-SUBRC NE 0.
                    "WA_PAYMENT-MANDT = SY-MANDT.
                    WA_PAYMENT-SBORDERNO = HH_HEADER-ORDERNO.
                    WA_PAYMENT-ORDERTYPE = HH_HEADER-ORDERTYPE.
                    WA_PAYMENT-KUNNR = HH_HEADER-CUSTOMERNO.
                    WA_PAYMENT-ORDERDATE = HH_HEADER-ORDERDATE.
                    WA_PAYMENT-SALESMANNO = HH_HEADER-SALESREP.
                    WA_PAYMENT-AMOUNT = HH_HEADER-TOTAL.
                    INSERT YSP_VS_PAYMENT FROM WA_PAYMENT.
                  ENDIF.
                  "INSERT ACCOUNTING DOCUMENT
                ENDIF.

                INSERT YSP_VS_HH_H FROM HH_HEADER.


                COMMIT WORK AND WAIT.

              ELSE. "EXISTS
                CALL FUNCTION 'NUMBER_GET_NEXT'
                  EXPORTING
                    NR_RANGE_NR = '01'
                    OBJECT      = 'YSP_VS_LOG'
                  IMPORTING
                    NUMBER      = WA_LOG-SERIAL.

                WA_LOG-ORDERTYPE = HH_HEADER-ORDERTYPE.
                WA_LOG-ORDERNO = HH_HEADER-ORDERNO.
                WA_LOG-TYPE = 'W'.
                WA_LOG-MSGNUMBER = 900.
                WA_LOG-MESSAGE = 'Order already exists in SAP in YSP_VS_HH_H.'.
                WA_LOG-MSGDATE = SY-DATUM.
                WA_LOG-MSGTIME = SY-UZEIT.
*            APPEND WA_LOG TO LOG.
                INSERT YSP_VS_LOG FROM WA_LOG.
              ENDIF.
            ENDLOOP.

          ENDIF.

*--------------------------------------------------------------------*
          LOOP AT SHIP_H.
            UPDATE YSP_VS_SHIP_H SET STATUS = SHIP_H-STATUS
            WHERE SHIP_NUM = SHIP_H-SHIP_NUM.
          ENDLOOP.

          LOOP AT SHIP_UP.
            UPDATE YSP_VS_SHIP_UP SET CUST_LON = SHIP_UP-CUST_LON
            CUST_LAT = SHIP_UP-CUST_LAT DEL_DATE = SHIP_UP-DEL_DATE
            DEL_TIME = SHIP_UP-DEL_TIME DEL_LON = SHIP_UP-DEL_LON
            DEL_LAT = SHIP_UP-DEL_LAT DEL_STATUS = SHIP_UP-DEL_STATUS
            DEL_REASON = SHIP_UP-DEL_REASON
            WHERE DELIV_NUM = SHIP_UP-DELIV_NUM AND SHIP_NUM = SHIP_UP-SHIP_NUM.
          ENDLOOP.
*--------------------------------------------------------------------*

*-----------------------E-IINVOICING---------------------------------------------*
*          DATA: WA_EINV      LIKE LINE OF EINV_UP,
*                WA_EINV_UP   TYPE YSP_VS_EINV_UP,
*                WA_EINV_PICS LIKE LINE OF EINV_PICS ,
*                ZTEMP        TYPE  YSP_VS_EINV_UP .
*
*          LOOP AT EINV_UP INTO WA_EINV.
*            CLEAR: WA_EINV_UP.
*            WA_EINV_UP-VISIT_ID = WA_EINV-VISIT_ID.
*            WA_EINV_UP-ASEQ_ID = WA_EINV-ASEQ_ID.
*            WA_EINV_UP-CUST_NO = WA_EINV-CUST_NO.
*            WA_EINV_UP-NAT_ID = WA_EINV-NAT_ID.
*            WA_EINV_UP-NAT_ID_NAME = WA_EINV-NAT_ID_NAME.
*            WA_EINV_UP-TAX_REG_NO = WA_EINV-TAX_REG_NO.
*            WA_EINV_UP-TAX_REG_EXP = WA_EINV-TAX_REG_EXP.
*            WA_EINV_UP-TAX_REG_NAME = WA_EINV-TAX_REG_NAME.
*            WA_EINV_UP-NAT_ID_UPDATE = WA_EINV-NAT_ID_UPDATE.
*            WA_EINV_UP-TAX_REG_UPDATE = WA_EINV-TAX_REG_UPDATE.
*            WA_EINV_UP-UPDATE_TAX_EXPIRE_DATE = WA_EINV-UPDATE_TAX_EXPIRE_DATE.
*
*            IF WA_EINV_UP-NAT_ID_UPDATE = 'X'.
*              WA_EINV_UP-NAT_ID_APP_STAT = '5'.
*            ELSE.
*              WA_EINV_UP-NAT_ID_APP_STAT = ''.
*            ENDIF.
*
*            IF WA_EINV_UP-TAX_REG_UPDATE = 'X'.
*              WA_EINV_UP-TAX_REG_APP_STAT = '5'.
*            ELSE.
*              WA_EINV_UP-TAX_REG_APP_STAT = ''.
*            ENDIF.
*
* "" NEW
*            SELECT SINGLE * FROM YSP_VS_EINV_UP INTO ZTEMP WHERE VISIT_ID = WA_EINV-VISIT_ID
*              AND ASEQ_ID = WA_EINV-ASEQ_ID  AND CUST_NO = WA_EINV-CUST_NO .
*              "AND ( NAT_ID_APP_STAT <> '2' OR NAT_ID_APP_STAT <> '5'
*              "or TAX_REG_APP_STAT <> '2' OR TAX_REG_APP_STAT <> '5').
*              IF SY-SUBRC <> 0 .
*
*"added field UPDATE_TAX_EXPIRE_DATE in table YSP_VS_EINV_UP and structure YSP_VS_EINV_UP_S to update table message 1000002668
*
*          IF WA_EINV-UPDATE_TAX_EXPIRE_DATE = 'X'.
*            CLEAR WA_EINV_UP .
*            SELECT SINGLE * FROM YSP_VS_EINV_UP INTO WA_EINV_UP WHERE VISIT_ID = WA_EINV-VISIT_ID
*              AND ASEQ_ID = WA_EINV-ASEQ_ID  AND CUST_NO = WA_EINV-CUST_NO .
*            WA_EINV_UP-TAX_REG_EXP = WA_EINV-TAX_REG_EXP.
*            MODIFY YSP_VS_EINV_UP FROM WA_EINV_UP.
*          ELSEIF WA_EINV-UPDATE_TAX_EXPIRE_DATE IS INITIAL .
*          MODIFY YSP_VS_EINV_UP FROM WA_EINV_UP.
*          ENDIF.
***
*          MODIFY YSP_VS_EINV_UP FROM WA_EINV_UP.
*
*
*ENDIF.
*CLEAR : ZTEMP .
*          ENDLOOP.
*
*          LOOP AT EINV_PICS INTO WA_EINV_PICS.
*            MODIFY YSP_VS_EINV_PICS FROM WA_EINV_PICS.
*          ENDLOOP.
*-----------------------E-IINVOICING---------------------------------------------*

*-----------------------DYNAMIC BONUS BUY---------------------------------------------*
*          DATA: WA_PROMO_A3 LIKE LINE OF PROMO_A.
*
*          LOOP AT PROMO_A INTO WA_PROMO_A3.
*            UPDATE YSP_VS_PROMO_A SET STATUS = WA_PROMO_A3-STATUS CURR_USED = WA_PROMO_A3-CURR_USED
*            WHERE CUST_NO = WA_PROMO_A3-CUST_NO AND PROMOID = WA_PROMO_A3-PROMOID
*            AND DATE_TO = WA_PROMO_A3-DATE_TO.
*
*            CLEAR: WA_PROMO_A3.
*          ENDLOOP.
*-----------------------DYNAMIC BONUS BUY---------------------------------------------*

*      "$. Region ORDERS AND INVOICES
          CALL FUNCTION 'YSP_VS_ORDER_T1'
            EXPORTING
              SALESREP = SALESREP
              ROUTE_ID = ROUTEID
            IMPORTING
              STATUS   = STATUS.

          CALL FUNCTION 'YSP_VS_PAYMENT'
            EXPORTING
              SALESREP = SALESREP
            IMPORTING
              STATUS   = INV_STATUS.

          IF INV_STATUS = 9.
            STATUS = 9.
          ENDIF.

*      "$. Endregion ORDERS AND INVOICES

************** ADD Download today Invoices by Yasser ******************************

          REFRESH: HH_HEADER,HH_DETAILS,HH_DETAILS_DIS.

*          DATA: VISITPLANDETAILS TYPE STANDARD TABLE OF YSP_VS_VISIT_D,
*                CUSTOMERS        TYPE STANDARD TABLE OF YSP_VS_CUSTOMER.
*
*          DATA: WA_CUST   TYPE YSP_VS_CUSTOMER.
*
*          DATA: WA_HH_DETAILS     TYPE YSP_VS_HH_D,
*                WA_HH_DETAILS_DIS TYPE YSP_VS_HH_D_DIS.
*
*
*          REFRESH: VISITPLANDETAILS,CUSTOMERS.
*          SELECT * FROM YSP_VS_VISIT_D
*            INNER JOIN YSP_VS_VISIT_H
*            ON YSP_VS_VISIT_D~VISITPLAN EQ YSP_VS_VISIT_H~VISITPLAN
*            INTO CORRESPONDING FIELDS OF TABLE VISITPLANDETAILS
*            WHERE YSP_VS_VISIT_D~SALESREP = SALESREP AND DELFLAG NE 'X'.
*          IF VISITPLANDETAILS[] IS NOT INITIAL.
*            SELECT * FROM YSP_VS_CUSTOMER INTO TABLE CUSTOMERS
*              FOR ALL ENTRIES IN VISITPLANDETAILS
*              WHERE CUST_NO = VISITPLANDETAILS-CUSTOMER.
*
*            IF CUSTOMERS[] IS NOT INITIAL.
*              LOOP AT CUSTOMERS INTO WA_CUST.
*                GET HISTORY
*                GET HEADER
*                DATA: TYPE          LIKE VBRK-FKART,
*                      VBELN         LIKE VBRK-VBELN,
*                      CONDREC       LIKE VBRK-KNUMV,
*                      TOTALDISCOUNT LIKE KONV-KWERT. "PRCD_ELEMENTS-KWERT.
*                CLEAR: TYPE, VBELN,CONDREC.
*                CLEAR WA_HH_HEADER.
*
*                SELECT VBELN VKORG KUNAG FKDAT FKART KNUMV
*                  FROM VBRK "UP TO 10 ROWS
*                  INTO (WA_HH_HEADER-ORDERNO, WA_HH_HEADER-SALESORG,
*                  WA_HH_HEADER-CUSTOMERNO, WA_HH_HEADER-ORDERDATE,
*                  TYPE ,CONDREC)
*                  WHERE KUNAG = WA_CUST-CUST_NO AND FKSTO = ''
*                  AND FKART IN ('YF2','YR1','YR2','YR3')
*                  AND FKDAT LE SY-DATUM
*                  AND FKDAT GE HISTDATE
*                  ORDER BY FKDAT DESCENDING.
*                  CASE TYPE.
*                    WHEN 'YR1'. "Return w Reference
*                      WA_HH_HEADER-ORDERTYPE = 3.
*                    WHEN 'YR2'. "Return w/o Reference
*                      WA_HH_HEADER-ORDERTYPE = 3.
*                    WHEN 'YR3'. "Return - Expired
*                      WA_HH_HEADER-ORDERTYPE = 4.
*                    WHEN OTHERS.
*                      WA_HH_HEADER-ORDERTYPE = 2.
*                  ENDCASE.
*                  CLEAR TYPE.
*
*                  GET DETAILS
*                  MOVE WA_HH_HEADER-ORDERNO TO VBELN.
*                  UNPACK VBELN TO VBELN.
*                  CLEAR WA_HH_DETAILS.
*                  TOTALDISCOUNT = 0.
*                  SELECT VBELN AS ORDERNO
*                    POSNR AS SERIAL
*                    MATNR AS MAT_NO
*                    FKIMG AS QTY
*                    VRKME AS UOM
*                    CHARG AS BATCH
*                    UMVKZ AS QTY_CNUM
*                    UMVKN AS QTY_DENOM
*                    RET_QTY AS RET_QTY
*                    FROM VBRP
*                    LEFT OUTER JOIN YSP_VS_RET_REF ON  VBRP~VBELN = YSP_VS_RET_REF~RET_REF
*                                                   AND VBRP~POSNR = YSP_VS_RET_REF~RET_REF_ITEM
*                    INTO CORRESPONDING FIELDS OF WA_HH_DETAILS
*                    WHERE VBELN = VBELN AND FKIMG NE 0.
*                    WA_HH_DETAILS-ORDERTYPE = WA_HH_HEADER-ORDERTYPE.
*
*                    GET DISCOUNTS
*                    CLEAR WA_HH_DETAILS_DIS.
*                    SELECT
*                      STUNR AS DISSERIAL
*                      KNUMH AS COND_RECORD
*                      KSCHL AS COND_TYPE
*                      KRECH AS CALC_TYPE
*                      KBETR AS AMT_PRCNT
*                      KPEIN AS PER
*                      KMEIN AS PER_UOM
*                      KWERT AS DISCOUNT
*                      FROM KONV"PRCD_ELEMENTS
*                      INTO CORRESPONDING FIELDS OF WA_HH_DETAILS_DIS
*                      WHERE KNUMV = CONDREC
*                      AND KPOSN = WA_HH_DETAILS-SERIAL
*                      AND KSTAT NE 'X'
*                      AND KWERT NE 0.
*                      WA_HH_DETAILS_DIS-ORDERTYPE = WA_HH_HEADER-ORDERTYPE.
*                      WA_HH_DETAILS_DIS-ORDERNO = WA_HH_HEADER-ORDERNO.
*                      WA_HH_DETAILS_DIS-SERIAL = WA_HH_DETAILS-SERIAL.
*                      IF WA_HH_DETAILS_DIS-COND_TYPE NE 'MWST'.
*                        IF WA_HH_DETAILS_DIS-COND_TYPE EQ 'YPR0'.
*                          WA_HH_DETAILS_DIS-IS_PRICE = 'X'.
*                          WA_HH_DETAILS-UPRICE = WA_HH_DETAILS_DIS-AMT_PRCNT.
*                          WA_HH_DETAILS-PER = WA_HH_DETAILS_DIS-PER.
*                          WA_HH_DETAILS-PRUOM = WA_HH_DETAILS_DIS-PER_UOM.
*                          WA_HH_DETAILS-PRICETIMESQTY = WA_HH_DETAILS_DIS-DISCOUNT.
*                        ELSE.
*                          WA_HH_DETAILS_DIS-DISCOUNT = -1 * WA_HH_DETAILS_DIS-DISCOUNT.
*                          WA_HH_DETAILS_DIS-AMT_PRCNT = -1 * WA_HH_DETAILS_DIS-AMT_PRCNT.
*                          WA_HH_DETAILS-DISCOUNT = WA_HH_DETAILS-DISCOUNT + WA_HH_DETAILS_DIS-DISCOUNT.
*                        ENDIF.
*                        APPEND WA_HH_DETAILS_DIS TO HH_DETAILS_DIS.
*                      ELSE.
*                        WA_HH_DETAILS-TAXVAL = WA_HH_DETAILS_DIS-DISCOUNT.
*                      ENDIF.
*                      CLEAR WA_HH_DETAILS_DIS.
*                    ENDSELECT.
*                    WA_HH_DETAILS-TOTAL = WA_HH_DETAILS-PRICETIMESQTY - WA_HH_DETAILS-DISCOUNT + WA_HH_DETAILS-TAXVAL.
*
*                    WA_HH_HEADER-PRICETIMESQTY = WA_HH_HEADER-PRICETIMESQTY + WA_HH_DETAILS-PRICETIMESQTY.
*                    WA_HH_HEADER-TOTALTAXES = WA_HH_HEADER-TOTALTAXES + WA_HH_DETAILS-TAXVAL.
*                    WA_HH_HEADER-TOTALDISCOUNTS = WA_HH_HEADER-TOTALDISCOUNTS + WA_HH_DETAILS-DISCOUNT.
*                    WA_HH_HEADER-TOTAL = WA_HH_HEADER-TOTAL + WA_HH_DETAILS-TOTAL.
*
*                    APPEND WA_HH_DETAILS TO HH_DETAILS.
*                    CLEAR WA_HH_DETAILS.
*                  ENDSELECT.
*
*                  APPEND WA_HH_HEADER TO HH_HEADER.
*                  CLEAR WA_HH_HEADER.
*                  CLEAR: TYPE, VBELN,CONDREC.
*                ENDSELECT.
*
*              ENDLOOP.
*            ENDIF.
*          ENDIF.
          HISTDATEO = SY-DATUM.

************** END ADD Download today Invoices by Yasser ******************************
        ENDIF.
      ENDIF.

      WA_LOCK-FLAG = 'U'.
      WA_LOCK-SALESREP = SALESREP.
      MODIFY YSP_VS_LOCK FROM WA_LOCK.
      COMMIT WORK AND WAIT.

    ELSE.
      CALL FUNCTION 'NUMBER_GET_NEXT'
        EXPORTING
          NR_RANGE_NR = '01'
          OBJECT      = 'YSP_VS_LOG'
        IMPORTING
          NUMBER      = WA_LOG-SERIAL.

      WA_LOG-ORDERTYPE = 0.
      WA_LOG-ORDERNO = SALESREP.
      WA_LOG-TYPE = 'E'.
      WA_LOG-MSGNUMBER = 905.
      WA_LOG-MESSAGE = 'Sales Rep is already locked for Upload'.
      WA_LOG-MSGDATE = SY-DATUM.
      WA_LOG-MSGTIME = SY-UZEIT.
*            APPEND WA_LOG TO LOG.
      INSERT YSP_VS_LOG FROM WA_LOG.
      STATUS = 96.

    ENDIF.

  ELSE.
    CALL FUNCTION 'NUMBER_GET_NEXT'
      EXPORTING
        NR_RANGE_NR = '01'
        OBJECT      = 'YSP_VS_LOG'
      IMPORTING
        NUMBER      = WA_LOG-SERIAL.

    WA_LOG-ORDERTYPE = 0.
    WA_LOG-ORDERNO = SALESREP.
    WA_LOG-TYPE = 'E'.
    WA_LOG-MSGNUMBER = 905.
    WA_LOG-MESSAGE = 'Sales Rep is already locked for Upload'.
    WA_LOG-MSGDATE = SY-DATUM.
    WA_LOG-MSGTIME = SY-UZEIT.
*            APPEND WA_LOG TO LOG.
    INSERT YSP_VS_LOG FROM WA_LOG.
    STATUS = 96.
  ENDIF.
  DATA WA_YSP_VS_SYNC_L TYPE YSP_VS_SYNC_L.
  WA_YSP_VS_SYNC_L-SALESREP = SALESREP.
  WA_YSP_VS_SYNC_L-REG_NO = REG_NO.
  WA_YSP_VS_SYNC_L-SYNCDATE = SY-DATUM.
  WA_YSP_VS_SYNC_L-SYNCTIME = SY-UZEIT.
  WA_YSP_VS_SYNC_L-SYNCTYPE = 'U'.
  WA_YSP_VS_SYNC_L-SYNCSTATUS = STATUS.
  INSERT YSP_VS_SYNC_L FROM WA_YSP_VS_SYNC_L.

  CALL FUNCTION 'DEQUEUE_EYSP_VS_LOCK'
    EXPORTING
      MODE_YSP_VS_LOCK = 'E'
      MANDT            = SY-MANDT
      SALESREP         = SALESREP
*     X_SALESREP       = ' '
*     _SCOPE           = '3'
*     _SYNCHRON        = ' '
*     _COLLECT         = ' '
    .


ENDFUNCTION.
