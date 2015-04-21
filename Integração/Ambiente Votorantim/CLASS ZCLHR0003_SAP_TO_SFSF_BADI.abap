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

  constants C_ACTIVE type STRING value 'ACTIVE'. "#EC NOTEXT
  constants C_INACTIVE type STRING value 'INACTIVE'. "#EC NOTEXT

  methods GET_CENTRAL_PERSON
    importing
      !I_PERNR type ANY
      !I_BEGDA type BEGDA default '19000101'
      !I_ENDDA type ENDDA default '99991231'
    exporting
      !E_USERID type ANY .
  methods GET_HRP1001
    importing
      !I_PLVAR type PLOG-PLVAR default '01'
      !I_OTYPE type PLOG-OTYPE
      !I_OBJID type ANY
      !I_SUBTY type PLOG-SUBTY
      !I_BEGDA type PLOG-BEGDA default '19000101'
      !I_ENDDA type PLOG-ENDDA default '99991231'
      !I_SCLAS type ANY optional
      !I_SOBID type ANY optional
    exporting
      !ET_1001 type TABLE .
  methods GET_DIFF_DATES
    importing
      !I_BEGDA type SY-DATUM
      !I_ENDDA type SY-DATUM default SY-DATUM
    exporting
      !E_DAYS type I
      !E_MONTHS type I
      !E_YEARS type I .
  methods GET_HRP1000
    importing
      !I_PLVAR type PLOG-PLVAR default '01'
      !I_OTYPE type PLOG-OTYPE
      !I_OBJID type ANY
      !I_BEGDA type PLOG-BEGDA default '19000101'
      !I_ENDDA type PLOG-ENDDA default '99991231'
    exporting
      !ET_1000 type TABLE .
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
* | Instance Private Method ZCLHR0003_SAP_TO_SFSF_BADI->GET_DIFF_DATES
* +-------------------------------------------------------------------------------------------------+
* | [--->] I_BEGDA                        TYPE        SY-DATUM
* | [--->] I_ENDDA                        TYPE        SY-DATUM (default =SY-DATUM)
* | [<---] E_DAYS                         TYPE        I
* | [<---] E_MONTHS                       TYPE        I
* | [<---] E_YEARS                        TYPE        I
* +--------------------------------------------------------------------------------------</SIGNATURE>
METHOD get_diff_dates.

  CALL FUNCTION 'HR_99S_INTERVAL_BETWEEN_DATES'
    EXPORTING
      begda    = i_begda
      endda    = i_endda
    IMPORTING
      days     = e_days
      c_years  = e_years
      d_months = e_months.

ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCLHR0003_SAP_TO_SFSF_BADI->GET_HRP1000
* +-------------------------------------------------------------------------------------------------+
* | [--->] I_PLVAR                        TYPE        PLOG-PLVAR (default ='01')
* | [--->] I_OTYPE                        TYPE        PLOG-OTYPE
* | [--->] I_OBJID                        TYPE        ANY
* | [--->] I_BEGDA                        TYPE        PLOG-BEGDA (default ='19000101')
* | [--->] I_ENDDA                        TYPE        PLOG-ENDDA (default ='99991231')
* | [<---] ET_1000                        TYPE        TABLE
* +--------------------------------------------------------------------------------------</SIGNATURE>
METHOD get_hrp1000.

  DATA: l_objid TYPE plog-objid.

  l_objid = i_objid.

  CALL FUNCTION 'RH_READ_INFTY_1000'
    EXPORTING
      plvar            = i_plvar
      otype            = i_otype
      objid            = i_objid
      begda            = i_begda
      endda            = i_endda
    TABLES
      i1001            = et_1000
    EXCEPTIONS
      nothing_found    = 1
      wrong_condition  = 2
      wrong_parameters = 3
      OTHERS           = 4.

  IF sy-subrc <> 0.
*do_nothing
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
* | [--->] I_SCLAS                        TYPE        ANY(optional)
* | [--->] I_SOBID                        TYPE        ANY(optional)
* | [<---] ET_1001                        TYPE        TABLE
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD get_hrp1001.

    DATA: t_1001  TYPE TABLE OF hrp1001,
          l_objid TYPE plog-objid.

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
        i1001            = t_1001
      EXCEPTIONS
        nothing_found    = 1
        wrong_condition  = 2
        wrong_parameters = 3
        OTHERS           = 4.

    IF sy-subrc <> 0.
*do_nothing
    ENDIF.

    IF NOT i_sclas IS INITIAL.
      DELETE t_1001 WHERE sclas NE i_sclas.
    ENDIF.

    IF NOT i_sobid IS INITIAL.
      DELETE t_1001 WHERE sobid NE i_sobid.
    ENDIF.

    et_1001[] = t_1001[].

  ENDMETHOD.                    "get_hrp1001


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCLHR0003_SAP_TO_SFSF_BADI->ZIFHR0001_USER~ADDRESSLINE2
* +-------------------------------------------------------------------------------------------------+
* | [--->] I_PERNR                        TYPE        PERNR
* | [--->] I_INFTY                        TYPE        INFTY
* | [--->] I_SUBTY                        TYPE        SUBTY
* | [--->] I_MOLGA                        TYPE        MOLGA
* | [--->] I_EMPRESA                      TYPE        ZDEHR_EMPRESA_SF
* | [--->] IT_INFOTIPO                    TYPE        TABLE
* | [<-->] C_VALUE                        TYPE        ANY
* +--------------------------------------------------------------------------------------</SIGNATURE>
METHOD zifhr0001_user~addressline2.

  DATA: t_p0001 TYPE TABLE OF p0001,
        w_p0001 TYPE p0001.

  t_p0001[] = it_infotipo[].
  SORT t_p0001 BY begda DESCENDING.
  READ TABLE t_p0001 INTO w_p0001 INDEX 1.

  SELECT SINGLE stras
    FROM t500p
    INTO c_value
  WHERE persa EQ w_p0001-werks.

ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCLHR0003_SAP_TO_SFSF_BADI->ZIFHR0001_USER~CUSTOM02
* +-------------------------------------------------------------------------------------------------+
* | [--->] I_PERNR                        TYPE        PERNR
* | [--->] I_INFTY                        TYPE        INFTY
* | [--->] I_SUBTY                        TYPE        SUBTY
* | [--->] I_MOLGA                        TYPE        MOLGA
* | [--->] I_EMPRESA                      TYPE        ZDEHR_EMPRESA_SF
* | [--->] IT_INFOTIPO                    TYPE        TABLE
* | [<-->] C_VALUE                        TYPE        ANY
* +--------------------------------------------------------------------------------------</SIGNATURE>
METHOD zifhr0001_user~custom02.

  DATA: l_entrydate TYPE sy-datum.

* Considera apenas ENTRY DATE
  CALL FUNCTION 'HR_ENTRY_DATE'
    EXPORTING
      persnr               = i_pernr-pernr
    IMPORTING
      entrydate            = l_entrydate
    EXCEPTIONS
      entry_date_not_found = 1
      pernr_not_assigned   = 2
      OTHERS               = 3.
  IF sy-subrc <> 0.
* Implement suitable error handling here
  ENDIF.

  c_value = l_entrydate.

ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCLHR0003_SAP_TO_SFSF_BADI->ZIFHR0001_USER~CUSTOM03
* +-------------------------------------------------------------------------------------------------+
* | [--->] I_PERNR                        TYPE        PERNR
* | [--->] I_INFTY                        TYPE        INFTY
* | [--->] I_SUBTY                        TYPE        SUBTY
* | [--->] I_MOLGA                        TYPE        MOLGA
* | [--->] I_EMPRESA                      TYPE        ZDEHR_EMPRESA_SF
* | [--->] IT_INFOTIPO                    TYPE        TABLE
* | [<-->] C_VALUE                        TYPE        ANY
* +--------------------------------------------------------------------------------------</SIGNATURE>
METHOD zifhr0001_user~custom03.

  DATA: w_infty   TYPE p0001,
        w_1001    TYPE hrp1001,
        t_1001    TYPE TABLE OF hrp1001,
        t_infty   TYPE TABLE OF p0001,
        l_days    TYPE i,
        l_months  TYPE i,
        l_years   TYPE i,
        l_m_y     TYPE i.

  t_infty[] = it_infotipo[].
  READ TABLE t_infty INTO w_infty INDEX 1.

* Time in position
  me->get_hrp1001( EXPORTING i_otype = 'S'
                             i_objid = w_infty-plans
                             i_plvar = '01'
                             i_subty = 'A008'
                             i_sclas = 'P'
                             i_sobid = w_infty-pernr ).

  READ TABLE t_1001 INTO w_1001 INDEX 1.

  IF sy-subrc = 0.

    me->get_diff_dates( EXPORTING i_begda  = w_1001-begda
                        IMPORTING e_days   = l_days
                                  e_months = l_months
                                  e_years  = l_years ).

    IF l_years IS NOT INITIAL.
      l_m_y = l_years * 12.
      l_months = l_months - l_m_y.
    ELSE.
      l_months = l_months.
    ENDIF.

    c_value = l_years && 'Y' && l_months && 'M'.

  ENDIF.

ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCLHR0003_SAP_TO_SFSF_BADI->ZIFHR0001_USER~CUSTOM05
* +-------------------------------------------------------------------------------------------------+
* | [--->] I_PERNR                        TYPE        PERNR
* | [--->] I_INFTY                        TYPE        INFTY
* | [--->] I_SUBTY                        TYPE        SUBTY
* | [--->] I_MOLGA                        TYPE        MOLGA
* | [--->] I_EMPRESA                      TYPE        ZDEHR_EMPRESA_SF
* | [--->] IT_INFOTIPO                    TYPE        TABLE
* | [<-->] C_VALUE                        TYPE        ANY
* +--------------------------------------------------------------------------------------</SIGNATURE>
METHOD zifhr0001_user~custom05.

  DATA: w_infty TYPE p0002,
        t_infty TYPE TABLE OF p0002.

  t_infty[] = it_infotipo[].
  READ TABLE t_infty INTO w_infty INDEX 1.

  me->get_diff_dates( EXPORTING i_begda = w_infty-gbdat
                      IMPORTING e_years = c_value ).

ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCLHR0003_SAP_TO_SFSF_BADI->ZIFHR0001_USER~CUSTOM06
* +-------------------------------------------------------------------------------------------------+
* | [--->] I_PERNR                        TYPE        PERNR
* | [--->] I_INFTY                        TYPE        INFTY
* | [--->] I_SUBTY                        TYPE        SUBTY
* | [--->] I_MOLGA                        TYPE        MOLGA
* | [--->] I_EMPRESA                      TYPE        ZDEHR_EMPRESA_SF
* | [--->] IT_INFOTIPO                    TYPE        TABLE
* | [<-->] C_VALUE                        TYPE        ANY
* +--------------------------------------------------------------------------------------</SIGNATURE>
METHOD zifhr0001_user~custom06.
ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCLHR0003_SAP_TO_SFSF_BADI->ZIFHR0001_USER~CUSTOM07
* +-------------------------------------------------------------------------------------------------+
* | [--->] I_PERNR                        TYPE        PERNR
* | [--->] I_INFTY                        TYPE        INFTY
* | [--->] I_SUBTY                        TYPE        SUBTY
* | [--->] I_MOLGA                        TYPE        MOLGA
* | [--->] I_EMPRESA                      TYPE        ZDEHR_EMPRESA_SF
* | [--->] IT_INFOTIPO                    TYPE        TABLE
* | [<-->] C_VALUE                        TYPE        ANY
* +--------------------------------------------------------------------------------------</SIGNATURE>
METHOD zifhr0001_user~custom07.

  DATA: w_infty TYPE p0001,
        w_1001  TYPE hrp1001,
        t_infty TYPE TABLE OF p0001,
        t_1001  TYPE TABLE OF hrp1001.

  t_infty[] = it_infotipo[].
  READ TABLE t_infty INTO w_infty INDEX 1.

* Time in position
  me->get_hrp1001( EXPORTING i_otype = 'S'
                             i_objid = w_infty-plans
                             i_plvar = '01'
                             i_subty = 'A008'
                             i_sclas = 'P'
                             i_sobid = w_infty-pernr ).

  READ TABLE t_1001 INTO w_1001 INDEX 1.

  c_value = w_1001-begda.

ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCLHR0003_SAP_TO_SFSF_BADI->ZIFHR0001_USER~CUSTOM08
* +-------------------------------------------------------------------------------------------------+
* | [--->] I_PERNR                        TYPE        PERNR
* | [--->] I_INFTY                        TYPE        INFTY
* | [--->] I_SUBTY                        TYPE        SUBTY
* | [--->] I_MOLGA                        TYPE        MOLGA
* | [--->] I_EMPRESA                      TYPE        ZDEHR_EMPRESA_SF
* | [--->] IT_INFOTIPO                    TYPE        TABLE
* | [<-->] C_VALUE                        TYPE        ANY
* +--------------------------------------------------------------------------------------</SIGNATURE>
METHOD zifhr0001_user~custom08.

  DATA: t_1001  TYPE TABLE OF hrp1001,
        t_1000  TYPE TABLE OF hrp1000,
        t_infty TYPE TABLE OF p0001,
        w_1001  TYPE hrp1001,
        w_1000  TYPE hrp1000,
        w_infty TYPE p0001,
        l_objid TYPE p1000-objid.

  me->get_hrp1001( EXPORTING i_otype = 'S'
                             i_objid = w_infty-plans
                             i_subty = 'B007'
                             i_sclas = '1P'
                   IMPORTING et_1001 = t_1001 ).

  SORT t_1001 BY otype objid rsign relat sclas ASCENDING endda DESCENDING.
  READ TABLE t_1001 INTO w_1001 INDEX 1.

  IF sy-subrc = 0.
*ID do objeto Pipeline 1P
    l_objid = w_1001-sobid(8).

    me->get_hrp1000( EXPORTING i_otype = '1P'
                               i_objid = l_objid
                     IMPORTING et_1000 = t_1000 ).

    READ TABLE t_1000 INTO w_1000 INDEX 1.

    IF sy-subrc = 0.
      c_value = w_1000-stext.
    ENDIF.
  ENDIF.

ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCLHR0003_SAP_TO_SFSF_BADI->ZIFHR0001_USER~CUSTOM09
* +-------------------------------------------------------------------------------------------------+
* | [--->] I_PERNR                        TYPE        PERNR
* | [--->] I_INFTY                        TYPE        INFTY
* | [--->] I_SUBTY                        TYPE        SUBTY
* | [--->] I_MOLGA                        TYPE        MOLGA
* | [--->] I_EMPRESA                      TYPE        ZDEHR_EMPRESA_SF
* | [--->] IT_INFOTIPO                    TYPE        TABLE
* | [<-->] C_VALUE                        TYPE        ANY
* +--------------------------------------------------------------------------------------</SIGNATURE>
METHOD zifhr0001_user~custom09.

  DATA: w_infty TYPE p0021,
        t_infty TYPE TABLE OF p0021.

  DATA: l_days        TYPE i,
        l_months      TYPE i,
        l_months_sum  TYPE i,
        l_years       TYPE i,
        l_ano_ini     TYPE sy-datum,
        l_ano_fim     TYPE sy-datum,
        l_entrydate   TYPE sy-datum.

  t_infty[] = it_infotipo[].

  l_ano_ini = sy-datum(4) && '0101'.
  l_ano_fim = sy-datum(4) && '1231'.

  LOOP AT t_infty INTO w_infty.

* Dia considerados devem ser dias utlizados dentro do ano atual
    IF w_infty-begda LT l_ano_ini.
      w_infty-begda = l_ano_ini.
    ENDIF.

    IF w_infty-endda GT l_ano_fim.
      w_infty-endda = l_ano_fim.
    ENDIF.

* Obtem diferença entre as duas datas
    me->get_diff_dates( EXPORTING i_begda   = w_infty-begda
                        IMPORTING e_days    = l_days
                                  e_months  = l_months
                                  e_years   = l_years ).

* Para validação do ano inteiro a função retorna 11 e não 12 meses
    IF l_days >= 365.
      l_months = 12.
    ENDIF.
    l_months_sum = l_months_sum + l_months.

  ENDLOOP.

  l_months_sum = 12 - l_months_sum.

* Se Funcionário tiver sido contratado em menos de um ano
* a data de admissão deve ser levada em conta na hora do calculo
  IF l_entrydate > l_ano_ini.

* Obtem diferença entre as duas datas
    me->get_diff_dates( EXPORTING i_begda   = l_entrydate
                                  i_endda   = l_ano_fim
                        IMPORTING e_days    = l_days
                                  e_months  = l_months
                                  e_years   = l_years ).

    l_months_sum = l_months.

  ENDIF.

  c_value = l_months_sum.

ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCLHR0003_SAP_TO_SFSF_BADI->ZIFHR0001_USER~CUSTOM11
* +-------------------------------------------------------------------------------------------------+
* | [--->] I_PERNR                        TYPE        PERNR
* | [--->] I_INFTY                        TYPE        INFTY
* | [--->] I_SUBTY                        TYPE        SUBTY
* | [--->] I_MOLGA                        TYPE        MOLGA
* | [--->] I_EMPRESA                      TYPE        ZDEHR_EMPRESA_SF
* | [--->] IT_INFOTIPO                    TYPE        TABLE
* | [<-->] C_VALUE                        TYPE        ANY
* +--------------------------------------------------------------------------------------</SIGNATURE>
METHOD zifhr0001_user~custom11.

  DATA: w_infty     TYPE p0001,
        t_infty     TYPE TABLE OF p0001,
        t_rpbenerr  TYPE STANDARD TABLE OF rpbenerr,
        t_phifi     TYPE STANDARD TABLE OF phifi,
        l_entrydate TYPE sy-datum,
        l_leavedate TYPE sy-datum.

  t_infty[] = it_infotipo[].
  READ TABLE t_infty INTO w_infty INDEX 1.

  CALL FUNCTION 'HR_CLM_GET_ENTRY_LEAVE_DATE'
    EXPORTING
      pernr       = w_infty-pernr
      begda       = '18000101'
      endda       = '99991231'
    IMPORTING
      hire_date   = l_entrydate
      fire_date   = l_leavedate
    TABLES
      error_table = t_rpbenerr
      phifi       = t_phifi.

  c_value = l_leavedate.

ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCLHR0003_SAP_TO_SFSF_BADI->ZIFHR0001_USER~DEPARTMENT
* +-------------------------------------------------------------------------------------------------+
* | [--->] I_PERNR                        TYPE        PERNR
* | [--->] I_INFTY                        TYPE        INFTY
* | [--->] I_SUBTY                        TYPE        SUBTY
* | [--->] I_MOLGA                        TYPE        MOLGA
* | [--->] I_EMPRESA                      TYPE        ZDEHR_EMPRESA_SF
* | [--->] IT_INFOTIPO                    TYPE        TABLE
* | [<-->] C_VALUE                        TYPE        ANY
* +--------------------------------------------------------------------------------------</SIGNATURE>
METHOD zifhr0001_user~department.

  DATA: w_infty               TYPE p0001,
        t_infty               TYPE TABLE OF p0001,
        t_org_units           TYPE hap_t_hrsobid,
        w_org_units           TYPE hrsobid,
        t_org_units_found     TYPE hap_t_hrsobid,
        w_org_units_found     TYPE hrsobid,
        t_1001                TYPE TABLE OF hrp1001,
        t_1000                TYPE TABLE OF hrp1000,
        w_1001                TYPE hrp1001,
        w_1000                TYPE hrp1000,
        l_objid               TYPE p1000-objid.

  t_infty[] = it_infotipo[].
  READ TABLE t_infty INTO w_infty INDEX 1.

  l_objid = w_infty-orgeh.

  DO 500 TIMES.
*Encontrar ligação entre unidade organizacional e diretoria 5O
*Leitura do Objeto O ligação B007
    me->get_hrp1001( EXPORTING i_otype = 'O'
                               i_objid = l_objid
                               i_subty = 'B007'
                     IMPORTING et_1001 = t_1001 ).

*Elimina todos os objetos diferentes de 5O
    DELETE t_1001 WHERE sclas NE '5O'.

    SORT t_1001 BY objid begda DESCENDING.

    IF NOT t_1001[] IS INITIAL.
      LOOP AT t_1001 INTO w_1001.
        CHECK sy-datum BETWEEN w_1001-begda AND w_1001-endda.

        me->get_hrp1000( EXPORTING i_otype = 'O'
                                   i_objid = l_objid
                         IMPORTING et_1000 = t_1000 ).

*Mantem o Objeto mais recente por idioma
        SORT t_1000 BY objid langu begda DESCENDING.
        DELETE ADJACENT DUPLICATES FROM t_1000 COMPARING objid langu.

        READ TABLE t_1000 INTO w_1000 WITH KEY objid = l_objid.

        IF sy-subrc = 0.
          c_value = w_1000-stext.
        ELSE.
          READ TABLE t_1000 INTO w_1000 INDEX 1.
          c_value = w_1000-stext.
        ENDIF.
        EXIT.
      ENDLOOP.
      EXIT.
    ELSE.

      REFRESH: t_org_units, t_org_units_found.

      w_org_units-plvar = '01'.
      w_org_units-otype = 'E'.
      w_org_units-sobid = l_objid.
      APPEND w_org_units TO t_org_units.

* Pega a Unid. Org. um nível acima e procura a Diretoria
      CALL FUNCTION 'HRHAP_SEL_ORG_UNIT_OF_ORG_UNIT'
        EXPORTING
          t_org_units       = t_org_units
          from_date         = w_infty-endda
          to_date           = w_infty-endda
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
        l_objid = w_org_units_found-sobid(8).
      ELSE.
        EXIT.
      ENDIF.

    ENDIF.

  ENDDO.

ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCLHR0003_SAP_TO_SFSF_BADI->ZIFHR0001_USER~DIVISION
* +-------------------------------------------------------------------------------------------------+
* | [--->] I_PERNR                        TYPE        PERNR
* | [--->] I_INFTY                        TYPE        INFTY
* | [--->] I_SUBTY                        TYPE        SUBTY
* | [--->] I_MOLGA                        TYPE        MOLGA
* | [--->] I_EMPRESA                      TYPE        ZDEHR_EMPRESA_SF
* | [--->] IT_INFOTIPO                    TYPE        TABLE
* | [<-->] C_VALUE                        TYPE        ANY
* +--------------------------------------------------------------------------------------</SIGNATURE>
METHOD zifhr0001_user~division.

  DATA: w_infty TYPE p0001,
        t_infty TYPE TABLE OF p0001.

  t_infty[] = it_infotipo[].
  READ TABLE t_infty INTO w_infty INDEX 1.

  SELECT SINGLE butxt
    INTO c_value
    FROM t001
   WHERE bukrs EQ w_infty-bukrs.

ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCLHR0003_SAP_TO_SFSF_BADI->ZIFHR0001_USER~GENDER
* +-------------------------------------------------------------------------------------------------+
* | [--->] I_PERNR                        TYPE        PERNR
* | [--->] I_INFTY                        TYPE        INFTY
* | [--->] I_SUBTY                        TYPE        SUBTY
* | [--->] I_MOLGA                        TYPE        MOLGA
* | [--->] I_EMPRESA                      TYPE        ZDEHR_EMPRESA_SF
* | [--->] IT_INFOTIPO                    TYPE        TABLE
* | [<-->] C_VALUE                        TYPE        ANY
* +--------------------------------------------------------------------------------------</SIGNATURE>
method ZIFHR0001_USER~GENDER.


endmethod.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCLHR0003_SAP_TO_SFSF_BADI->ZIFHR0001_USER~HIREDATE
* +-------------------------------------------------------------------------------------------------+
* | [--->] I_PERNR                        TYPE        PERNR
* | [--->] I_INFTY                        TYPE        INFTY
* | [--->] I_SUBTY                        TYPE        SUBTY
* | [--->] I_MOLGA                        TYPE        MOLGA
* | [--->] I_EMPRESA                      TYPE        ZDEHR_EMPRESA_SF
* | [--->] IT_INFOTIPO                    TYPE        TABLE
* | [<-->] C_VALUE                        TYPE        ANY
* +--------------------------------------------------------------------------------------</SIGNATURE>
METHOD zifhr0001_user~hiredate.

  DATA: w_infty     TYPE p0001,
        t_infty     TYPE TABLE OF p0001,
        l_entrydate TYPE sy-datum.

  t_infty[] = it_infotipo[].
  READ TABLE t_infty INTO w_infty INDEX 1.

* Considera apenas ENTRY DATE
  CALL FUNCTION 'HR_ENTRY_DATE'
    EXPORTING
      persnr               = w_infty-pernr
    IMPORTING
      entrydate            = l_entrydate
    EXCEPTIONS
      entry_date_not_found = 1
      pernr_not_assigned   = 2
      OTHERS               = 3.
  IF sy-subrc <> 0.
* Implement suitable error handling here
  ENDIF.

  c_value = l_entrydate.

ENDMETHOD.


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
* | Instance Public Method ZCLHR0003_SAP_TO_SFSF_BADI->ZIFHR0001_USER~LOCATION
* +-------------------------------------------------------------------------------------------------+
* | [--->] I_PERNR                        TYPE        PERNR
* | [--->] I_INFTY                        TYPE        INFTY
* | [--->] I_SUBTY                        TYPE        SUBTY
* | [--->] I_MOLGA                        TYPE        MOLGA
* | [--->] I_EMPRESA                      TYPE        ZDEHR_EMPRESA_SF
* | [--->] IT_INFOTIPO                    TYPE        TABLE
* | [<-->] C_VALUE                        TYPE        ANY
* +--------------------------------------------------------------------------------------</SIGNATURE>
METHOD zifhr0001_user~location.

  DATA: w_infty TYPE p0001,
        t_infty TYPE TABLE OF p0001.

  t_infty[] = it_infotipo[].
  READ TABLE t_infty INTO w_infty INDEX 1.

  SELECT SINGLE name1
    INTO c_value
    FROM t500p
   WHERE persa EQ w_infty-werks.

ENDMETHOD.


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


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCLHR0003_SAP_TO_SFSF_BADI->ZIFHR0001_USER~STATUS
* +-------------------------------------------------------------------------------------------------+
* | [--->] I_PERNR                        TYPE        PERNR
* | [--->] I_INFTY                        TYPE        INFTY
* | [--->] I_SUBTY                        TYPE        SUBTY
* | [--->] I_MOLGA                        TYPE        MOLGA
* | [--->] I_EMPRESA                      TYPE        ZDEHR_EMPRESA_SF
* | [--->] IT_INFOTIPO                    TYPE        TABLE
* | [<-->] C_VALUE                        TYPE        ANY
* +--------------------------------------------------------------------------------------</SIGNATURE>
METHOD zifhr0001_user~status.

  DATA: w_infty TYPE p0000,
        t_infty TYPE TABLE OF p0000.

  t_infty[] = it_infotipo[].
  READ TABLE t_infty INTO w_infty INDEX 1.

  CASE w_infty-stat2.
    WHEN '2'.
      c_value = c_inactive.
    WHEN '3'.
      c_value = c_active.
  ENDCASE.

ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCLHR0003_SAP_TO_SFSF_BADI->ZIFHR0001_USER~TITLE
* +-------------------------------------------------------------------------------------------------+
* | [--->] I_PERNR                        TYPE        PERNR
* | [--->] I_INFTY                        TYPE        INFTY
* | [--->] I_SUBTY                        TYPE        SUBTY
* | [--->] I_MOLGA                        TYPE        MOLGA
* | [--->] I_EMPRESA                      TYPE        ZDEHR_EMPRESA_SF
* | [--->] IT_INFOTIPO                    TYPE        TABLE
* | [<-->] C_VALUE                        TYPE        ANY
* +--------------------------------------------------------------------------------------</SIGNATURE>
METHOD zifhr0001_user~title.

  DATA: w_infty TYPE p0001,
        t_infty TYPE TABLE OF p0001.

  t_infty[] = it_infotipo[].
  READ TABLE t_infty INTO w_infty INDEX 1.

  SELECT stext UP TO 1 ROWS
    FROM hrp1000
    INTO c_value
    WHERE plvar   EQ '01'
      AND otype   EQ 'S'
      AND objid   EQ w_infty-plans
      AND istat   EQ 'I'
      AND begda   LE w_infty-begda
      AND endda   GE w_infty-begda.
  ENDSELECT.

ENDMETHOD.
ENDCLASS.	