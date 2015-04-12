*======================================================================*
*                                                                      *
*                        HR Solutions Tecnologia                       *
*                                                                      *
*======================================================================*
* Empresa     : GLOBAL                                                 *
* ID          : <ID de desenvolvimento fornecido pela VID, se houver>  *
* Programa    : ZGLIHR0005_SUCCESSFACTORS_API                          *
* Tipo        : Interface Outbound                                     *
* Módulo      : HCM                                                    *
* Transação   : <Transação(ões) utilizada(s)>                          *
* Descrição   : Programa para carregar os dados dos empregados para o  *
*               SuccessFactors utilizando SFAPI (WebService)           *
* Autor       : Rodney Amancio - HRST                                  *
* Data        : 06/04/2015                                             *
*----------------------------------------------------------------------*
* Changes History                                                      *
*----------------------------------------------------------------------*
* Data       | Autor     | Request    | Descrição                      *
*------------|-----------|------------|--------------------------------*
* 02/04/2014 |           |            | Início do desenvolvimento      *
*------------|-----------|------------|--------------------------------*
*======================================================================*

REPORT  zglihr0005_successfactors_api.

*----------------------------------------------------------------------*
* Tabela Transparente                                                  *
*----------------------------------------------------------------------*
TABLES: pernr.

*----------------------------------------------------------------------*
* Infotipos                                                            *
*----------------------------------------------------------------------*
INFOTYPES:  0000,
            0001,
            0002,
            0004,
            0006,
            0105.

*----------------------------------------------------------------------*
* Types                                                                *
*----------------------------------------------------------------------*
TYPES: BEGIN OF y_log,
         pernr       TYPE pernr-pernr,
         type        TYPE c,
         message     TYPE string,
       END OF y_log,

       BEGIN OF y_user,
        externalid  TYPE string,
        name        TYPE string,
       END OF y_user,

       BEGIN OF y_bkg_insideworkexper,
         start_date  TYPE string,
       END OF y_bkg_insideworkexper.

*----------------------------------------------------------------------*
* Tabela Interna                                                       *
*----------------------------------------------------------------------*
DATA: t_log                       TYPE TABLE OF y_log,
      t_parametros                TYPE TABLE OF ztbhr_sfsf_voran,
      t_user                      TYPE TABLE OF y_user,
      t_bkg_insideworkexper       TYPE TABLE OF y_bkg_insideworkexper.

*----------------------------------------------------------------------*
* Work Área                                                            *
*----------------------------------------------------------------------*
DATA: w_log                       LIKE LINE OF t_log,
      w_user                      LIKE LINE OF t_user,
      w_bkg_insideworkexper       LIKE LINE OF t_bkg_insideworkexper.

*----------------------------------------------------------------------*
* Constantes                                                           *
*----------------------------------------------------------------------*
CONSTANTS: c_error                TYPE c VALUE 'E',
           c_warning              TYPE c VALUE 'W',
           c_success              TYPE c VALUE 'S'.

*----------------------------------------------------------------------*
* Início da Execução
*----------------------------------------------------------------------*
START-OF-SELECTION.

  PERFORM zf_seleciona_parametros.

  CHECK t_parametros IS NOT INITIAL.

GET pernr.

  PERFORM zf_processa_reg_empregado.

*----------------------------------------------------------------------*
* Fim da Execução
*----------------------------------------------------------------------*
END-OF-SELECTION.

*======================================================================*
*                                                                      *
*                     Declarações de Rotinas                           *
*                                                                      *
*======================================================================*
*&---------------------------------------------------------------------*
*&      Form  zf_seleciona_parametros
*&---------------------------------------------------------------------*
FORM zf_seleciona_parametros.

* Seleciona as parametrizações dos campos mapeados para processamento
* através da interface de integração do SuccessFactors x SAP HCM
  SELECT *
    INTO TABLE t_parametros
    FROM ztbhr_sfsf_voran
*    WHERE begda LE pn-begda
*     AND  endda GE pn-endda
   ORDER BY tabela_sf campo_sf.

  IF sy-subrc NE 0.

*   Erro ao selecionar parâmetros de mapeamento da integração
    PERFORM zf_log USING space c_error text-001 space.

  ENDIF.

ENDFORM.                    "zf_seleciona_parametros

*&---------------------------------------------------------------------*
*&      Form  ZF_PROCESSA_REG_EMPREGADO
*&---------------------------------------------------------------------*
FORM zf_processa_reg_empregado .

  DATA: t_header_param    LIKE t_parametros.

  DATA: w_header_param    LIKE LINE OF t_parametros,
        w_parametro       LIKE LINE OF t_parametros.

  DATA: l_nome_objeto(40) TYPE c,
        l_nome_infty      TYPE infty.

  FIELD-SYMBOLS: <f_tabela_sf>    TYPE table,
                 <f_tabela_sap>   TYPE table,
                 <f_workarea_sap> TYPE ANY,
                 <f_workarea_sf>  TYPE ANY,
                 <f_campo_sf>     TYPE ANY,
                 <f_campo_sap>    TYPE ANY.

  t_header_param[] = t_parametros[].

  DELETE ADJACENT DUPLICATES FROM t_header_param COMPARING tabela_sf.

  LOOP AT t_header_param INTO w_header_param.

*/ Cria dinâmicamente as tabelas e workareas
    CONCATENATE 'T_' w_header_param-tabela_sf INTO l_nome_objeto.
    ASSIGN (l_nome_objeto) TO <f_tabela_sf>.
    IF sy-subrc NE 0. PERFORM zf_log USING space c_error 'Erro ao Associar campo' l_nome_objeto. ENDIF.

    CONCATENATE 'W_' w_header_param-tabela_sf INTO l_nome_objeto.
    ASSIGN (l_nome_objeto) TO <f_workarea_sf>.
    IF sy-subrc NE 0. PERFORM zf_log USING space c_error 'Erro ao Associar campo' l_nome_objeto. ENDIF.

    CONCATENATE 'P' w_header_param-infty '[]' INTO l_nome_objeto.
    ASSIGN (l_nome_objeto) TO <f_tabela_sap>.
    IF sy-subrc NE 0. PERFORM zf_log USING space c_error 'Erro ao Associar campo' l_nome_objeto. ENDIF.
*/

*/ Ordena a tabela de forma descendente para que o primeiro registro seja o mais novo
    SORT <f_tabela_sap> DESCENDING.

    LOOP AT <f_tabela_sap> ASSIGNING <f_workarea_sap>.

      LOOP AT t_parametros INTO w_parametro WHERE tabela_sf EQ w_header_param-tabela_sf.

        ASSIGN COMPONENT w_parametro-campo_sf  OF STRUCTURE <f_workarea_sf>  TO <f_campo_sf>.
        IF sy-subrc NE 0. PERFORM zf_log USING space c_error 'Erro ao Associar campo ' w_parametro-campo_sf. ENDIF.

        ASSIGN COMPONENT w_parametro-campo_sap OF STRUCTURE <f_workarea_sap> TO <f_campo_sap>.
        IF sy-subrc NE 0. PERFORM zf_log USING space c_error 'Erro ao Associar campo ' w_parametro-campo_sap. ENDIF.

        IF <f_campo_sap> IS ASSIGNED AND <f_campo_sf> IS ASSIGNED.

*/ Preenche o campo que será enviado para o SuccessFactors
          <f_campo_sf> = <f_campo_sap>.
*/

*/ Se houver tratamento via BADi
          IF NOT w_parametro-tratamento IS INITIAL.
            PERFORM zf_call_badi USING w_parametro CHANGING <f_campo_sf>.
          ENDIF.
*/
        ENDIF.
      ENDLOOP.

      IF <f_workarea_sf> IS ASSIGNED AND <f_tabela_sf> IS ASSIGNED.
        APPEND <f_workarea_sf> TO <f_tabela_sf>.
      ENDIF.

*/ Se não for uma tabela de histórico (Background) então registra apenas o primeiro registro
      IF w_header_param-historico IS INITIAL.
        EXIT.
      ENDIF.
*/

    ENDLOOP.

  ENDLOOP.

ENDFORM.                    " ZF_PROCESSA_REG_EMPREGADO

*&---------------------------------------------------------------------*
*&      Form  ZF_LOG
*&---------------------------------------------------------------------*
FORM zf_log  USING p_pernr
                   p_type
                   p_message1
                   p_message2.

  w_log-pernr   = p_pernr.
  w_log-type    = p_type.
  CONCATENATE p_message1 p_message2 INTO w_log-message.

  APPEND w_log TO t_log.
  CLEAR w_log.

ENDFORM.                    " ZF_LOG

*&---------------------------------------------------------------------*
*&      Form  ZF_CALL_BADI
*&---------------------------------------------------------------------*
FORM zf_call_badi USING p_parametros LIKE LINE OF t_parametros
               CHANGING c_campo_sf.

  FIELD-SYMBOLS: <f_tabela_infty>    TYPE ANY TABLE.

  DATA: lv_method       TYPE string,
        lv_infty        TYPE string,
        lv_result_badi  TYPE string,
        lv_obj_badi     TYPE REF TO zclhr0003_sap_to_sfsf_badi.

  DATA: lo_ex_root TYPE REF TO cx_root.

  CONCATENATE 'P' p_parametros-infty '[]' INTO lv_infty.
  ASSIGN (lv_infty) TO <f_tabela_infty>.

  CREATE OBJECT lv_obj_badi.
  CONCATENATE 'ZIFHR0001_' p_parametros-tabela_sf '~' p_parametros-campo_sf INTO lv_method.

  TRY.

      CALL METHOD lv_obj_badi->(lv_method)
        EXPORTING
          i_pernr     = pernr
          i_infty     = p_parametros-infty
          i_subty     = p_parametros-subty
          it_infotipo = <f_tabela_infty>
        CHANGING
          r_value     = c_campo_sf.

    CATCH cx_root INTO lo_ex_root.
      PERFORM zf_log USING pernr-pernr c_warning text-002 p_parametros-campo_sf.

  ENDTRY.

ENDFORM.                    " ZF_CALL_BADI