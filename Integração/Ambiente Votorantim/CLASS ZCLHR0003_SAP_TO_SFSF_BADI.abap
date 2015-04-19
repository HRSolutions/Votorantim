*----------------------------------------------------------------------*
*       CLASS ZCLHR0003_SAP_TO_SFSF_BADI DEFINITION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS zclhr0003_sap_to_sfsf_badi DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES zifhr0001_user .
  PROTECTED SECTION.
  PRIVATE SECTION.

    METHODS get_hrp1001
      IMPORTING
        !i_plvar TYPE plog-plvar DEFAULT '01'
        !i_otype TYPE plog-otype
        !i_objid TYPE any
        !i_subty TYPE plog-subty
        !i_begda TYPE plog-begda DEFAULT '19000101'
        !i_endda TYPE plog-endda DEFAULT '99991231'
      EXPORTING
        !et_1001 TYPE table .
ENDCLASS.



CLASS ZCLHR0003_SAP_TO_SFSF_BADI IMPLEMENTATION.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCLHR0003_SAP_TO_SFSF_BADI->GET_HRP1001
* +-------------------------------------------------------------------------------------------------+
* | [--->] I_PLVAR                        TYPE        PLOG-PLVAR (default ='01')
* | [--->] I_OTYPE                        TYPE        PLOG-OTYPE
* | [--->] I_OBJID                        TYPE        ANY
* | [--->] I_SUBTY                        TYPE        PLOG-SUBTY
* | [--->] I_BEGDA                        TYPE        PLOG-BEGDA (default ='19000101')
* | [--->] I_ENDDA                        TYPE        PLOG-ENDDA (default ='99991231')
* | [<---] ET_1001                        TYPE        TABLE
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD get_hrp1001.

    DATA: l_objid TYPE plog-objid.

    l_objid = i_objid.

    CALL FUNCTION 'RH_READ_INFTY_1001'
      EXPORTING
        plvar            = i_plvar
        otype            = i_otype
        objid            = i_objid
        subty            = i_subty
        begda            = i_begda
        endda            = i_endda
      TABLES
        i1001            = et_1001
      EXCEPTIONS
        nothing_found    = 1
        wrong_condition  = 2
        wrong_parameters = 3
        OTHERS           = 4.

    IF sy-subrc <> 0.
*do_nothing
    ENDIF.

  ENDMETHOD.                    "get_hrp1001


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCLHR0003_SAP_TO_SFSF_BADI->ZIFHR0001_USER~HREXTERNALID
* +-------------------------------------------------------------------------------------------------+
* | [--->] I_PERNR                        TYPE        PERNR
* | [--->] I_INFTY                        TYPE        INFTY
* | [--->] I_SUBTY                        TYPE        SUBTY
* | [--->] I_MOLGA                        TYPE        MOLGA
* | [--->] I_EMPRESA                      TYPE        ZDEHR_EMPRESA_SF
* | [--->] IT_INFOTIPO                    TYPE        TABLE
* | [<-->] C_VALUE                        TYPE        ANY
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD zifhr0001_user~hrexternalid.

    DATA: t_1001  TYPE TABLE OF hrp1001,
          t_p0001 TYPE TABLE OF p0001.

    DATA: w_p0001 TYPE p0001,
          w_1001  TYPE hrp1001.

    DATA: t_org_units           TYPE hap_t_hrsobid,
          w_org_units           TYPE hrsobid,
          t_org_units_found     TYPE hap_t_hrsobid,
          w_org_units_found     TYPE hrsobid.

    t_p0001[] = it_infotipo[].

    SORT t_p0001 BY endda DESCENDING.
    READ TABLE t_p0001 INTO w_p0001 INDEX 1.

    DO.

      me->get_hrp1001( EXPORTING i_plvar = '01'
                                 i_otype = 'O'
                                 i_objid = w_p0001-orgeh
                                 i_subty = 'ADHO'
*                               i_begda = w_p0001-begda
*                               i_endda = w_p0001-endda
                       IMPORTING et_1001 = t_1001 ).

*Elimina todos os objetos diferentes de S
      DELETE t_1001 WHERE sclas <> 'S'.

      SORT t_1001 BY objid begda DESCENDING.

      READ TABLE t_1001 INTO w_1001 INDEX 1.

      IF sy-subrc EQ 0.

        me->get_hrp1001( EXPORTING i_plvar = '01'
                                   i_otype = 'S'
                                   i_objid = w_1001-sobid(8)
                                   i_subty = 'A008'
*                               i_begda = w_p0001-begda
*                               i_endda = w_p0001-endda
                         IMPORTING et_1001 = t_1001 ).

*Elimina todos os objetos diferentes de P
        DELETE t_1001 WHERE sclas <> 'P'.

        SORT t_1001 BY objid begda DESCENDING.

        READ TABLE t_1001 INTO w_1001 INDEX 1.

        me->get_hrp1001( EXPORTING i_plvar = '01'
                                   i_otype = 'P'
                                   i_objid = w_1001-sobid(8)
                                   i_subty = 'A209'
                         IMPORTING et_1001 = t_1001 ).

*Elimina todos os objetos diferentes de CP
        DELETE t_1001 WHERE sclas <> 'CP'.
        SORT t_1001 BY objid begda DESCENDING.

        READ TABLE t_1001 INTO w_1001 INDEX 1.

        me->get_hrp1001( EXPORTING i_plvar = '01'
                                   i_otype = 'CP'
                                   i_objid = w_1001-sobid(8)
                                   i_subty = 'B209'
                         IMPORTING et_1001 = t_1001 ).

*Ordenar os registros encontrados e selecionar o SOBID com o menor BEGDA.
        SORT t_1001 BY sobid.
        DELETE ADJACENT DUPLICATES FROM t_1001 COMPARING objid.

*Pega o PERNR mais antigo
        READ TABLE t_1001 INTO w_1001 INDEX 1.

        IF sy-subrc = 0.
          c_value = w_1001-sobid.
        ENDIF.

      ELSE.

        w_org_units-plvar = '01'.
        w_org_units-otype = 'O'.
        w_org_units-sobid = w_p0001-orgeh.
        APPEND w_org_units TO t_org_units.

* Pega a Unid. Org. um nível acima e procura a Diretoria
        CALL FUNCTION 'HRHAP_SEL_ORG_UNIT_OF_ORG_UNIT'
          EXPORTING
            t_org_units       = t_org_units
            from_date         = w_p0001-endda
            to_date           = w_p0001-endda
            up_or_down        = 'U'
          IMPORTING
            t_org_units_found = t_org_units_found
          EXCEPTIONS
            no_org_unit_found = 1
            OTHERS            = 2.

        IF sy-subrc <> 0.
* MESSAGE ID SY-MSGID TYPE SY-MSGTY NUMBER SY-MSGNO
*         WITH SY-MSGV1 SY-MSGV2 SY-MSGV3 SY-MSGV4.
        ENDIF.

*Pega a Unid. Org. acima
        READ TABLE t_org_units_found INTO w_org_units_found INDEX 1.

        IF sy-subrc = 0.
          c_value = w_org_units_found-sobid(8).
        ELSE.
          c_value = 'NO_HR'.
          EXIT.
        ENDIF.

      ENDIF.

    ENDDO.

  ENDMETHOD.                    "zifhr0001_user~hrexternalid


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCLHR0003_SAP_TO_SFSF_BADI->ZIFHR0001_USER~ID
* +-------------------------------------------------------------------------------------------------+
* | [--->] I_PERNR                        TYPE        PERNR
* | [--->] I_INFTY                        TYPE        INFTY
* | [--->] I_SUBTY                        TYPE        SUBTY
* | [--->] I_MOLGA                        TYPE        MOLGA
* | [--->] I_EMPRESA                      TYPE        ZDEHR_EMPRESA_SF
* | [--->] IT_INFOTIPO                    TYPE        TABLE
* | [<-->] C_VALUE                        TYPE        ANY
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD zifhr0001_user~id.
  ENDMETHOD.                    "ZIFHR0001_USER~ID
ENDCLASS.