*----------------------------------------------------------------------*
*       CLASS ZCLHR0003_SAP_TO_SFSF_BADI DEFINITION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
class ZCLHR0003_SAP_TO_SFSF_BADI definition
  public
  final
  create public .

public section.

  interfaces ZIFHR0001_USER .
  PROTECTED SECTION.
private section.

  methods GET_HRP1001
    importing
      !I_PLVAR type PLOG-PLVAR default '01'
      !I_OTYPE type PLOG-OTYPE
      !I_OBJID type ANY
      !I_SUBTY type PLOG-SUBTY
      !I_BEGDA type PLOG-BEGDA default '19000101'
      !I_ENDDA type PLOG-ENDDA default '99991231'
    exporting
      !ET_1001 type TABLE .
  methods GET_CENTRAL_PERSON
    importing
      !I_PERNR type ANY
      !I_BEGDA type BEGDA default '19000101'
      !I_ENDDA type ENDDA default '99991231'
    exporting
      !E_USERID type ANY .
ENDCLASS.



CLASS ZCLHR0003_SAP_TO_SFSF_BADI IMPLEMENTATION.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCLHR0003_SAP_TO_SFSF_BADI->GET_CENTRAL_PERSON
* +-------------------------------------------------------------------------------------------------+
* | [--->] I_PERNR                        TYPE        ANY
* | [--->] I_BEGDA                        TYPE        BEGDA (default ='19000101')
* | [--->] I_ENDDA                        TYPE        ENDDA (default ='99991231')
* | [<---] E_USERID                       TYPE        ANY
* +--------------------------------------------------------------------------------------</SIGNATURE>
METHOD get_central_person.

  DATA: t_1001 TYPE TABLE OF hrp1001.

  DATA: w_objid TYPE hrp1001-objid,
        w_1001  TYPE hrp1001.

  DATA: l_pernr TYPE pernr-pernr.

  l_pernr = i_pernr.

*Leitura do Objeto CP
  me->get_hrp1001( EXPORTING i_plvar = '01'
                             i_otype = 'P'
                             i_objid = l_pernr
                             i_subty = 'A209'
                             i_begda = i_begda
                             i_endda = i_endda
                   IMPORTING et_1001 = t_1001 ).

*Elimina todos os objetos diferentes de CP
  DELETE t_1001 WHERE sclas <> 'CP'.

  SORT t_1001 BY objid begda DESCENDING.

*Pega o ID do CP
  READ TABLE t_1001 INTO w_1001 INDEX 1.

  IF sy-subrc = 0.

*Leitura do Objeto P
    me->get_hrp1001( EXPORTING i_plvar = '01'
                               i_otype = 'CP'
                               i_objid = w_1001-sobid(8)
                               i_subty = 'B209'
                               i_begda = i_begda
                               i_endda = i_endda
                     IMPORTING et_1001 = t_1001 ).

*Ordenar os registros encontrados e selecionar o SOBID com o menor BEGDA.
    SORT t_1001 BY sobid.

    DELETE ADJACENT DUPLICATES FROM t_1001 COMPARING objid.

*Pega o PERNR mais antigo
    READ TABLE t_1001 INTO w_1001 INDEX 1.

    IF sy-subrc = 0.
      e_userid = w_1001-sobid.
    ENDIF.

  ENDIF.

ENDMETHOD.


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

    DO 500 TIMES.

      me->get_hrp1001( EXPORTING i_plvar = '01'
                                 i_otype = 'O'
                                 i_objid = w_p0001-orgeh
                                 i_subty = 'ADHO'
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
                         IMPORTING et_1001 = t_1001 ).

*Elimina todos os objetos diferentes de P
        DELETE t_1001 WHERE sclas <> 'P'.

        SORT t_1001 BY objid begda DESCENDING.

        READ TABLE t_1001 INTO w_1001 INDEX 1.

        me->get_central_person(
         EXPORTING
           i_pernr  = w_1001-objid(8)
         IMPORTING
           e_userid = c_value ).

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
          w_p0001-orgeh = w_org_units_found-sobid(8).
        ELSE.
          c_value = 'NO_HR'.
          EXIT.
        ENDIF.

      ENDIF.

    ENDDO.

* Se HR for ele mesmo deve enviar NO_HR
    IF  c_value NE 'NO_HR'.
      IF c_value = i_pernr-pernr.
        c_value = 'NO_HR'.
      ENDIF.
    ENDIF.

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


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCLHR0003_SAP_TO_SFSF_BADI->ZIFHR0001_USER~MANAGEREXTERNALID
* +-------------------------------------------------------------------------------------------------+
* | [--->] I_PERNR                        TYPE        PERNR
* | [--->] I_INFTY                        TYPE        INFTY
* | [--->] I_SUBTY                        TYPE        SUBTY
* | [--->] I_MOLGA                        TYPE        MOLGA
* | [--->] I_EMPRESA                      TYPE        ZDEHR_EMPRESA_SF
* | [--->] IT_INFOTIPO                    TYPE        TABLE
* | [<-->] C_VALUE                        TYPE        ANY
* +--------------------------------------------------------------------------------------</SIGNATURE>
METHOD zifhr0001_user~managerexternalid.

  DATA: t_objects           TYPE hap_t_hrsobid,
        w_objects           TYPE hrsobid,
        t_target_types      TYPE hap_t_type,
        w_target_types      TYPE hap_s_type,
        t_objects_base      TYPE hap_t_hrsobid,
        w_objects_base      TYPE hrsobid,
        l_man_pernr         TYPE pa0001-pernr,
        l_sobid             TYPE hrsobid-sobid,
        w_p0001             TYPE p0001,
        t_p0001             TYPE TABLE OF p0001.

  CLEAR: w_objects, t_objects_base[], w_target_types, t_target_types[], t_objects[].

  t_p0001[] = it_infotipo[].
  READ TABLE t_p0001 INTO w_p0001 INDEX 1.

  w_objects_base-plvar = '01'.
  w_objects_base-otype = 'P'.
  w_objects_base-sobid = i_pernr-pernr.
  APPEND w_objects_base TO t_objects_base.

  w_target_types-type = 'P'.
  APPEND w_target_types TO t_target_types.

*Busca o pernr do gerente
  CALL FUNCTION 'HRHAP_0ROLE_MANAGER_DIRECT'
    EXPORTING
      t_objects_base = t_objects_base
      from_date      = w_p0001-endda
      to_date        = w_p0001-endda
      t_target_types = t_target_types
    IMPORTING
      t_objects      = t_objects.

*Elimina ele mesmo da tabela
  l_sobid = i_pernr-pernr.
  DELETE t_objects WHERE sobid = l_sobid.

  READ TABLE t_objects INDEX 1 INTO w_objects_base.

* Se encontrar, busca o UserId do gerente
  IF sy-subrc = 0.
*UserID
    me->get_central_person(
     EXPORTING
       i_pernr  = w_objects_base-sobid(8)
     IMPORTING
       e_userid = c_value ).
  ELSE.
*    p_w_saida_ui_manager = c_no_manager.
  ENDIF.

ENDMETHOD.
ENDCLASS.