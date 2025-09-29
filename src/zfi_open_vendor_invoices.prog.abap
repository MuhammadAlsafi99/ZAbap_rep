*&---------------------------------------------------------------------*
*& Report ZFI_OPEN_VENDOR_INVOICES
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT ZFI_OPEN_VENDOR_INVOICES.

  CLASS ZCL_VENDOR_PAYMENT_BASE DEFINITION ABSTRACT.
    PROTECTED SECTION.
    DATA : vendor       TYPE lifnr,
           invoice_num  TYPE belnr_d,
           company_code TYPE bukrs,
           amount       TYPE wrbtr,
           currency     TYPE waers.

    CLASS-DATA : invoice_count TYPE I .
  ENDCLASS.
