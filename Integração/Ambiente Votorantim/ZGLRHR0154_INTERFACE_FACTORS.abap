*======================================================================*
*                                                                      *
*                        HR Solutions Tecnologia                       *
*                                                                      *
*======================================================================*
* Empresa     : GLOBAL                                                 *
* ID          : 1903                                                   *
* Programa    : ZGLRHR0154_INTERFACE_FACTORS                           *
* Tipo        : Interface Outbound                                     *
* Módulo      : HCM                                                    *
* Transação   : <Transação(ões) utilizada(s)>                          *
* Descrição   : Programa para carregar os dados dos empregados para o  *
*               SuccessFactors utilizando SFAPI (WebService)           *
* Autor       : Fábrica HRST                                           *
* Data        : 06/04/2015                                             *
*----------------------------------------------------------------------*
* Changes History                                                      *
*----------------------------------------------------------------------*
* Data       | Autor     | Request    | Descrição                      *
*------------|-----------|------------|--------------------------------*
* 06/04/2014 |           | E03K9XY383 | Início do desenvolvimento      *
*------------|-----------|------------|--------------------------------*
*======================================================================*

REPORT zglrhr0154_interface_factors.

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
            0105,
*            0008,
            0465.
*            2001.

*----------------------------------------------------------------------*
* Types                                                                *
*----------------------------------------------------------------------*
TYPES: BEGIN OF y_tabelas,
        tabela_sf       TYPE string,
        tabela_interna  TYPE string,
       END OF y_tabelas.

*----------------------------------------------------------------------*
* Tabela Interna                                                       *
*----------------------------------------------------------------------*
DATA: t_log                       TYPE TABLE OF ztbhr_sfsf_log,
      t_parametros                TYPE TABLE OF ztbhr_sfsf_param,
      t_credenciais               TYPE TABLE OF ztbhr_sfsf_crede,
      t_picklist                  TYPE TABLE OF ztbhr_sfsf_pickl,
      t_tabelas                   TYPE TABLE OF y_tabelas.

*----------------------------------------------------------------------*
* Work Área                                                            *
*----------------------------------------------------------------------*
DATA: w_log                       LIKE LINE OF t_log,
      w_tabelas                   LIKE LINE OF t_tabelas.

*----------------------------------------------------------------------*
* Constantes                                                           *
*----------------------------------------------------------------------*
CONSTANTS: c_error                TYPE c VALUE 'E',
           c_warning              TYPE c VALUE 'W',
           c_success              TYPE c VALUE 'S',
           c_prefixo_badi(10)     TYPE c VALUE 'ZIFHR0001_'.

*----------------------------------------------------------------------*
* Variáveis                                                           *
*----------------------------------------------------------------------*
DATA: v_idlog TYPE ztbhr_sfsf_log-idlog.

*----------------------------------------------------------------------*
* Field-Symbol Global                                                  *
*----------------------------------------------------------------------*
FIELD-SYMBOLS: <f_t_user> TYPE table,
               <f_t_01>   TYPE table,
               <f_t_02>   TYPE table,
               <f_t_03>   TYPE table,
               <f_t_04>   TYPE table,
               <f_t_05>   TYPE table,
               <f_t_06>   TYPE table,
               <f_t_07>   TYPE table,
               <f_t_08>   TYPE table,
               <f_t_09>   TYPE table,
               <f_t_10>   TYPE table,
               <f_t_11>   TYPE table,
               <f_t_12>   TYPE table,
               <f_t_13>   TYPE table,
               <f_t_14>   TYPE table,
               <f_t_15>   TYPE table,
               <f_t_16>   TYPE table,
               <f_t_17>   TYPE table,
               <f_t_18>   TYPE table,
               <f_t_19>   TYPE table,
               <f_t_20>   TYPE table.

*----------------------------------------------------------------------*
* Tela de Seleção                                                      *
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE text-000.
PARAMETERS: p_delta AS CHECKBOX.
SELECTION-SCREEN END OF BLOCK b1.

*----------------------------------------------------------------------*
* Início da Execução
*----------------------------------------------------------------------*
START-OF-SELECTION.

  PERFORM zf_log USING space c_success 'Início da Execução'(013) space.

  IF NOT p_delta IS INITIAL.
    PERFORM zf_get_delta.
  ENDIF.

  PERFORM zf_seleciona_parametros.

  PERFORM zf_cria_tabelas_internas.

  CHECK t_parametros IS NOT INITIAL.

GET pernr.

  PERFORM zf_processa_reg_empregado.

*----------------------------------------------------------------------*
* Fim da Execução
*----------------------------------------------------------------------*
END-OF-SELECTION.

  PERFORM zf_call_sfapi_user.
  PERFORM zf_call_sfapi_bkg.

  PERFORM zf_log USING space c_success 'Fim da Execução'(014) space.
  PERFORM zf_gravar_log.

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
    FROM ztbhr_sfsf_param
   WHERE begda LE sy-datum
     AND endda GE sy-datum
     AND infty NE space
   ORDER BY tabela_sf campo_sf.

  IF sy-subrc NE 0.

*/  Erro ao selecionar parâmetros de mapeamento da integração
    PERFORM zf_log USING space c_error text-001 space.

  ENDIF.

*/ Seleciona os dados de Picklist para conversão
  SELECT *
    INTO TABLE t_picklist
    FROM ztbhr_sfsf_pickl
   ORDER BY picklistid externalcode.

  IF sy-subrc NE 0.

*/  Nenhuma Picklist cadastrada
    PERFORM zf_log USING space c_error text-004 space.

  ENDIF.
*/

*/ Seleciona os dados de Credenciais para Acesso ao SuccessFactors
  SELECT *
    INTO TABLE t_credenciais
    FROM ztbhr_sfsf_crede.

  IF sy-subrc NE 0.

*/  Nenhuma Credencial Cadastrada
    PERFORM zf_log USING space c_error text-010 space.

  ENDIF.
*/

ENDFORM.                    "zf_seleciona_parametros

*&---------------------------------------------------------------------*
*&      Form  ZF_PROCESSA_REG_EMPREGADO
*&---------------------------------------------------------------------*
FORM zf_processa_reg_empregado .

  DATA: t_header_param    LIKE t_parametros.

  DATA: w_header_param    LIKE LINE OF t_parametros,
        w_parametro       LIKE LINE OF t_parametros.

  DATA: l_nome_objeto(40) TYPE c,
        l_nome_infty      TYPE infty,
        l_empresa         TYPE char10,
        l_operacao        TYPE char10,
        l_infty           TYPE string.

  FIELD-SYMBOLS: <f_tabela_sf>    TYPE table,
                 <f_tabela_sap>   TYPE table,
                 <f_workarea_sap> TYPE any,
                 <f_workarea_sf>  TYPE any,
                 <f_campo_sf>     TYPE any,
                 <f_campo_sap>    TYPE any,
                 <f_infty>        TYPE any.

  PERFORM zf_define_empresa CHANGING l_empresa.

  t_header_param[] = t_parametros[].
  DELETE ADJACENT DUPLICATES FROM t_header_param COMPARING tabela_sf.

  LOOP AT t_header_param INTO w_header_param WHERE empresa EQ l_empresa.

*/  Associa a tabela de IT dinamicamente
    CONCATENATE 'P' w_header_param-infty '[]' INTO l_nome_objeto.
    ASSIGN (l_nome_objeto) TO <f_tabela_sap>.
    IF sy-subrc NE 0. PERFORM zf_log USING space c_error 'Erro ao Associar Infotipo'(007) l_nome_objeto. ENDIF.
*/

*/  Ordena a tabela de forma descendente para que o primeiro registro seja o mais novo
    SORT <f_tabela_sap> DESCENDING.

    LOOP AT <f_tabela_sap> ASSIGNING <f_workarea_sap>.

*/    Associa dinamicamente a estrutura da tabela para enviar ao SuccessFactors
      CLEAR w_tabelas.
      READ TABLE t_tabelas INTO w_tabelas WITH KEY tabela_sf = w_header_param-tabela_sf.
      l_nome_objeto = w_tabelas-tabela_interna.
      ASSIGN (l_nome_objeto) TO <f_tabela_sf>.
      IF sy-subrc NE 0. PERFORM zf_log USING space c_error 'Erro ao Associar Tabela Interna'(005) l_nome_objeto. ENDIF.
*/

*/    Associa dinamicamente a WorkArea para gravação dos dados para enviar ao SuccessFactors.
      APPEND INITIAL LINE TO <f_tabela_sf> ASSIGNING <f_workarea_sf>.
      IF sy-subrc NE 0. PERFORM zf_log USING space c_error 'Erro ao Associar Work Area'(006) l_nome_objeto. ENDIF.
*/

      LOOP AT t_parametros INTO w_parametro WHERE tabela_sf EQ w_header_param-tabela_sf.

        UNASSIGN: <f_campo_sf>, <f_campo_sap>, <f_infty>.
        CLEAR: l_infty.

        ASSIGN COMPONENT w_parametro-campo_sf  OF STRUCTURE <f_workarea_sf>  TO <f_campo_sf>.
        IF sy-subrc NE 0. PERFORM zf_log USING space c_error 'Erro ao Associar campo '(008) w_parametro-campo_sf. ENDIF.

        l_infty = 'P' && w_parametro-infty.
        ASSIGN (l_infty) TO <f_infty>.
        IF sy-subrc NE 0. PERFORM zf_log USING space c_error 'Erro ao Associar Infotipo '(008) l_infty. ENDIF.

        IF <f_infty> IS ASSIGNED.
          PERFORM zf_reg_infty USING w_parametro <f_workarea_sap> CHANGING <f_infty>.
          ASSIGN COMPONENT w_parametro-campo_sap OF STRUCTURE <f_infty> TO <f_campo_sap>.
          IF sy-subrc NE 0. PERFORM zf_log USING space c_error 'Erro ao Associar campo '(008) w_parametro-campo_sap. ENDIF.
        ENDIF.

        IF <f_campo_sap> IS ASSIGNED AND <f_campo_sf> IS ASSIGNED.

*/        Preenche o campo que será enviado para o SuccessFactors
          <f_campo_sf> = <f_campo_sap>.
*/

*/        Se houver tratamento via BADi
          IF NOT w_parametro-tratamento IS INITIAL.
            PERFORM zf_call_badi USING w_parametro CHANGING <f_campo_sf>.
          ENDIF.
*/

*/        Faz a conversão da Picklist, caso o campo tenha associação com uma
          IF NOT w_parametro-picklist IS INITIAL.
            PERFORM zf_convert_picklist USING w_parametro CHANGING <f_campo_sf>.
          ENDIF.
*/

*/        Se o campo for do tipo data, formata segundo a tabela de parametrização
          IF w_parametro-tipo_campo EQ '1'.
            PERFORM zf_formata_data CHANGING <f_campo_sf>.
          ENDIF.
*/

        ENDIF.
      ENDLOOP.

*/    Verifica para as tabelas Backgrounds qual operação deve ser feita, INSERT ou UPDATE
      IF NOT w_header_param-historico IS INITIAL AND <f_workarea_sf> IS ASSIGNED.
        PERFORM zf_verifica_operacao USING w_header_param <f_workarea_sf> CHANGING l_operacao.
      ENDIF.
*/

      IF <f_workarea_sf> IS ASSIGNED AND <f_tabela_sf> IS ASSIGNED.

*/      Preenche o campo empresa para diferenciar as rotas de comunicação do WebService (SFAPI)
        ASSIGN COMPONENT 'EMPRESA' OF STRUCTURE <f_workarea_sf> TO <f_campo_sf>.
        <f_campo_sf> = l_empresa.
*/

*/      Preenche o campo operação para diferenciar o método que será invocado da SFAPI
        ASSIGN COMPONENT 'OPERACAO' OF STRUCTURE <f_workarea_sf> TO <f_campo_sf>.
        <f_campo_sf> = l_operacao.
*/

      ENDIF.

*/    Se não for uma tabela de histórico (Background) então registra apenas o primeiro registro
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

  IF t_log[] IS INITIAL.
    SELECT MAX( idlog )
      INTO v_idlog
      FROM ztbhr_sfsf_log.

    ADD 1 TO v_idlog.
  ENDIF.

  w_log-idlog   = v_idlog.
  w_log-pernr   = p_pernr.
  w_log-type    = p_type.
  CONCATENATE p_message1 p_message2 INTO w_log-message SEPARATED BY space.
  w_log-uname   = sy-uname.

  GET TIME.
  w_log-data    = sy-datum.
  w_log-hora    = sy-uzeit.

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
  IF sy-subrc NE 0. PERFORM zf_log USING space c_error 'Erro ao Associar Infotipo '(007) p_parametros-infty. ENDIF.
  CHECK <f_tabela_infty> IS ASSIGNED.

  CREATE OBJECT lv_obj_badi.
  CONCATENATE c_prefixo_badi p_parametros-tabela_sf '~' p_parametros-campo_sf INTO lv_method.

  TRY.

      CALL METHOD lv_obj_badi->(lv_method)
        EXPORTING
          i_pernr     = pernr
          i_empresa   = p_parametros-empresa
          i_molga     = p_parametros-molga
          i_infty     = p_parametros-infty
          i_subty     = p_parametros-subty
          it_infotipo = <f_tabela_infty>
        CHANGING
          r_value     = c_campo_sf.

    CATCH cx_root INTO lo_ex_root.
      PERFORM zf_log USING pernr-pernr c_warning text-002 p_parametros-campo_sf.

  ENDTRY.

ENDFORM.                    " ZF_CALL_BADI

*&---------------------------------------------------------------------*
*&      Form  ZF_CONVERT_PICKLIST
*&---------------------------------------------------------------------*
FORM zf_convert_picklist  USING    p_parametro LIKE LINE OF t_parametros
                          CHANGING c_campo_sf.

  DATA: w_picklist LIKE LINE OF t_picklist.

  READ TABLE t_picklist INTO w_picklist WITH KEY picklistid   = p_parametro-picklist
                                                 externalcode = c_campo_sf
                                          BINARY SEARCH.

  IF sy-subrc EQ 0.

    c_campo_sf = w_picklist-id.

  ELSE.

    PERFORM zf_log USING pernr-pernr c_error text-003 p_parametro-campo_sf.

  ENDIF.

ENDFORM.                    " ZF_CONVERT_PICKLIST

*&---------------------------------------------------------------------*
*&      Form  ZF_DEFINE_EMPRESA
*&---------------------------------------------------------------------*
FORM zf_define_empresa  CHANGING c_empresa.

*/ Lógica para definir a qual empresa (Instância SuccessFactors) o
*  empregado está associado.
  SELECT SINGLE empresa_sf
    INTO c_empresa
    FROM ztbhr_sfsf_empre
   WHERE empresa_sap  EQ p0001-bukrs
     AND begda        LE sy-datum
     AND endda        GE sy-datum.

  IF sy-subrc NE 0.
    PERFORM zf_log USING pernr-pernr c_error 'Nenhuma Empresa SF cadastrada para a Empresa SAP'(012) p0001-bukrs.
  ENDIF.
*/

ENDFORM.                    " ZF_DEFINE_EMPRESA

*&---------------------------------------------------------------------*
*&      Form  ZF_CALL_SFAPI_USER
*&---------------------------------------------------------------------*
FORM zf_call_sfapi_user .

  DATA: t_request_data  TYPE zsfi_dt_operation_request_tab2,
        t_sfobject      TYPE zsfi_dt_operation_request__tab.

  DATA: w_parametro     LIKE LINE OF t_parametros,
        w_request_data  LIKE LINE OF t_request_data,
        w_sfobject      LIKE LINE OF t_sfobject,
        w_credenciais   LIKE LINE OF t_credenciais.

  DATA: l_sessionid   TYPE string,
        l_batchsize   TYPE string,
        l_count_reg   TYPE i.

  FIELD-SYMBOLS: <f_field>    TYPE any,
                 <f_w_user>   TYPE any,
                 <f_empresa>  TYPE any.

  LOOP AT t_credenciais INTO w_credenciais.

*/ Monta a Estrutura do XML para a comunicação com o SuccessFactors
    LOOP AT <f_t_user> ASSIGNING <f_w_user>.

      ASSIGN COMPONENT 'EMPRESA' OF STRUCTURE <f_w_user> TO <f_empresa>.
      CHECK <f_empresa> EQ w_credenciais-empresa.

      LOOP AT t_parametros INTO w_parametro WHERE empresa   EQ w_credenciais-empresa
                                              AND tabela_sf EQ 'USER'.

        w_request_data-key   = w_parametro-campo_sf.
        ASSIGN COMPONENT w_parametro-campo_sf OF STRUCTURE <f_w_user> TO <f_field>.
        w_request_data-value = <f_field>.
        APPEND w_request_data TO t_request_data.
        CLEAR w_request_data.
        UNASSIGN <f_field>.

      ENDLOOP.

      w_sfobject-entity = 'USER'.
      w_sfobject-data[] = t_request_data[].
      APPEND w_sfobject TO t_sfobject.

      UNASSIGN: <f_empresa>.
      CLEAR: w_request_data,
             t_request_data[].

    ENDLOOP.
*/

*/ Efetua a operação UPSERT com o XML criado no item anterior
    PERFORM zf_call_upsert USING w_credenciais
                                 t_sfobject.
*/

  ENDLOOP.

ENDFORM.                    " ZF_CALL_SFAPI_USER

*&---------------------------------------------------------------------*
*&      Form  ZF_LOGIN_SUCCESSFACTORS
*&---------------------------------------------------------------------*
FORM zf_login_successfactors  USING    p_empresa
                              CHANGING c_sessionid
                                       c_batchsize.

  DATA: l_o_login TYPE REF TO zsfi_co_si_login_request,
        l_o_erro  TYPE REF TO cx_root,
        l_text    TYPE string.

  DATA: w_credenciais LIKE LINE OF t_credenciais,
        w_request     TYPE zsfi_mt_login_request,
        w_response    TYPE zsfi_mt_login_response.

*/ Lógica responsável por efetuar o Login no SuccessFactors

  CREATE OBJECT l_o_login.

*/ Seleciona os dados de acesso da empresa
  READ TABLE t_credenciais INTO w_credenciais WITH KEY empresa = p_empresa BINARY SEARCH.
  IF sy-subrc NE 0.
    PERFORM zf_log USING space c_error text-009 p_empresa.
  ENDIF.
*/

*/ Converte a senha para efetuar o Login
  PERFORM zf_decode_pass CHANGING w_credenciais-password.
*/

  c_batchsize = w_credenciais-batchsize.

*/ Se não foi cadastrado um BatchSize para a empresa, assume o valor Default
  IF c_batchsize IS INITIAL.
    c_batchsize = '500'.
  ENDIF.
*/

  w_request-mt_login_request-credential-company_id = w_credenciais-companyid.
  w_request-mt_login_request-credential-username   = w_credenciais-username.
  w_request-mt_login_request-credential-password   = w_credenciais-password.

  TRY.

      CALL METHOD l_o_login->si_login_request
        EXPORTING
          output = w_request
        IMPORTING
          input  = w_response.

      IF w_response-mt_login_response-session_id IS INITIAL.
        PERFORM zf_log USING space c_error 'Erro ao Efetuar Login para a Empresa'(015) p_empresa.
      ELSE.
        c_sessionid = w_response-mt_login_response-session_id.
        PERFORM zf_log USING space c_error 'Login Efetuado com Sucesso para a Empresa'(016) p_empresa.
        PERFORM zf_log USING space c_error 'SessionID'(017) c_sessionid.
      ENDIF.

    CATCH cx_ai_system_fault INTO l_o_erro.
      PERFORM zf_log USING space c_error 'Erro ao Efetuar Login para a Empresa'(015) p_empresa.

      l_text = l_o_erro->get_text( ).
      PERFORM zf_log USING space c_error l_text space.

  ENDTRY.

*/

ENDFORM.                    " ZF_LOGIN_SUCCESSFACTORS

*&---------------------------------------------------------------------*
*&      Form  zf_logout_successfactors
*&---------------------------------------------------------------------*
FORM zf_logout_successfactors CHANGING c_sessionid.

*/ Lógica responsável por efeutar o Logout no SuccessFactors

  CLEAR: c_sessionid.
*/

ENDFORM.                    "zf_logout_successfactors
*&---------------------------------------------------------------------*
*&      Form  ZF_DECODE_PASS
*&---------------------------------------------------------------------*
FORM zf_decode_pass CHANGING c_password.

  DATA: l_obj_utility TYPE REF TO cl_http_utility,
        l_pass        TYPE string.

  CREATE OBJECT l_obj_utility.

  l_pass = c_password.

  CALL METHOD l_obj_utility->decode_base64
    EXPORTING
      encoded = l_pass
    RECEIVING
      decoded = l_pass.

  c_password = l_pass.

ENDFORM.                    " ZF_DECODE_PASS

*&---------------------------------------------------------------------*
*&      Form  ZF_VERIFICA_OPERACAO
*&---------------------------------------------------------------------*
FORM zf_verifica_operacao USING p_parametro   LIKE LINE OF t_parametros
                                p_workarea_sf
                       CHANGING c_operacao.

  DATA: l_tabela_hist TYPE string,
        l_query       TYPE string,
        l_tabela      TYPE REF TO data.

  FIELD-SYMBOLS: <f_tabela_hist> TYPE table.

* Define a tabela transparente que possui o histórico
  PERFORM zf_get_tabela_historico USING p_parametro CHANGING l_tabela_hist.

  PERFORM zf_monta_query USING p_workarea_sf l_tabela_hist CHANGING l_query.

  CREATE DATA l_tabela TYPE TABLE OF (l_tabela_hist).
  ASSIGN l_tabela->* TO <f_tabela_hist>.

  SELECT *
    INTO TABLE <f_tabela_hist>
    FROM (l_tabela_hist)
   WHERE (l_query).

  IF sy-subrc EQ 0.
    c_operacao = '_U'.
  ELSE.
    c_operacao = '_I'.
  ENDIF.

ENDFORM.                    " ZF_VERIFICA_OPERACAO

*&---------------------------------------------------------------------*
*&      Form  ZF_GET_TABELA_HISTORICO
*&---------------------------------------------------------------------*
FORM zf_get_tabela_historico  USING    p_parametro LIKE LINE OF t_parametros
                              CHANGING c_tabela_hist.

*/ Verifica qual a tabela transparente responsável por guardar o histórico
  SELECT SINGLE tabela_sap
    INTO c_tabela_hist
    FROM ztbhr_sfsf_bkg
   WHERE alias_sf EQ p_parametro-tabela_sf.

  IF sy-subrc NE 0.
    PERFORM zf_log USING space c_error 'Sem tabela SAP de histórico para a tabela' p_parametro-tabela_sf.
  ENDIF.

ENDFORM.                    " ZF_GET_TABELA_HISTORICO

*&---------------------------------------------------------------------*
*&      Form  ZF_MONTA_QUERY
*&---------------------------------------------------------------------*
FORM zf_monta_query USING p_workarea_sf
                          p_tabela_hist
                 CHANGING c_query.

  DATA: t_dd03l TYPE TABLE OF dd03l.

  DATA: w_dd03l TYPE dd03l.

  DATA: l_query TYPE string.

  FIELD-SYMBOLS: <f_campo_sf> TYPE any.

  SELECT *
    INTO TABLE t_dd03l
    FROM dd03l
   WHERE tabname   EQ p_tabela_hist
     AND fieldname NE 'MANDT'.

  LOOP AT t_dd03l INTO w_dd03l.

    ASSIGN COMPONENT w_dd03l-fieldname OF STRUCTURE p_workarea_sf TO <f_campo_sf>.

    CONCATENATE 'AND' w_dd03l-fieldname 'EQ' text-011 <f_campo_sf> text-011 INTO l_query SEPARATED BY space.

  ENDLOOP.

  c_query = l_query+4.

ENDFORM.                    " ZF_MONTA_QUERY

*&---------------------------------------------------------------------*
*&      Form  zf_formata_data
*&---------------------------------------------------------------------*
FORM zf_formata_data CHANGING c_data.

  DATA: l_data TYPE string.
*/ Formata a data para o padrão da API do SuccessFactors.
  CONCATENATE c_data(4) c_data+4(2) c_data+6(2) INTO l_data SEPARATED BY '-'.
  c_data = l_data.
*/

ENDFORM.                    "zf_formata_data

*&---------------------------------------------------------------------*
*&      Form  ZF_CALL_SFAPI_BKG
*&---------------------------------------------------------------------*
FORM zf_call_sfapi_bkg .

*  DATA: t_param_loc LIKE t_parametros.
*
*  DATA: w_param_loc LIKE LINE OF t_parametros,
*        w_parametro LIKE LINE OF t_parametros.
*
*  DATA: l_sessionid   TYPE string,
*        l_batchsize   TYPE string,
*        l_count_reg   TYPE i.
*
*  t_param_loc[] = t_user[].
*
*  SORT t_param_loc BY empresa tabela_sf.
*  DELETE ADJACENT DUPLICATES FROM t_user_loc COMPARING empresa tabela_sf.
*  DELETE t_param_loc WHERE tabela_sf EQ 'USER'.
*
*  LOOP AT t_param_loc INTO w_param_loc.
*
*    LOOP AT t_user INTO w_user WHERE empresa EQ w_user_loc-empresa.
*
**/    Efetua o Login no SuccessFactors baseado no Empresa que está sendo processada.
*      IF l_sessionid IS INITIAL.
*        PERFORM zf_login_successfactors USING w_user_loc-empresa CHANGING l_sessionid l_batchsize.
*      ENDIF.
**/
*
**/    Caso seja o último registro da empresa a processar, força o envio do lote mesmo não tendo chegado ao
**     valor máximo do BatchSize
*      AT END OF empresa.
*        l_count_reg = l_batchsize.
*      ENDAT.
**/
*
**/    Se a quantidade de registro chegar ao total definido no Batchsize, então envia o lote para o SuccessFactors
*      IF l_count_reg EQ l_batchsize.
*
**/ Lógica para o UPSERT no SuccessFactors.
**/
*
*      ENDIF.
**/
*
**/    Efetua o Logout no SuccessFactors.
*      PERFORM zf_logout_successfactors CHANGING l_sessionid.
**/
*
*    ENDLOOP.
*
*  ENDLOOP.

  DATA: t_request_data  TYPE zsfi_dt_operation_request_tab2,
         t_sfobject      TYPE zsfi_dt_operation_request__tab.

  DATA: w_parametro     LIKE LINE OF t_parametros,
        w_request_data  LIKE LINE OF t_request_data,
        w_sfobject      LIKE LINE OF t_sfobject,
        w_credenciais   LIKE LINE OF t_credenciais.

  DATA: l_sessionid   TYPE string,
        l_batchsize   TYPE string,
        l_count_reg   TYPE i,
        l_operacao    TYPE string.

  FIELD-SYMBOLS: <f_field>    TYPE any,
                 <f_empresa>  TYPE any,
                 <f_operacao> TYPE any,
                 <f_t_bkg>    TYPE table,
                 <f_w_bkg>    TYPE any.

  DELETE t_tabelas WHERE tabela_sf EQ 'USER'.

  LOOP AT t_credenciais INTO w_credenciais.

    LOOP AT t_tabelas INTO w_tabelas.

      ASSIGN (w_tabelas-tabela_interna) TO <f_t_bkg>.

      DO 2 TIMES.

        IF sy-index EQ 1.
          l_operacao = 'I'.
        ELSE.
          l_operacao = 'U'.
        ENDIF.

*/ Monta a Estrutura do XML para a comunicação com o SuccessFactors
        LOOP AT <f_t_bkg> ASSIGNING <f_w_bkg>.

          ASSIGN COMPONENT 'EMPRESA' OF STRUCTURE <f_w_bkg> TO <f_empresa>.
          CHECK <f_empresa> EQ w_credenciais-empresa.

          ASSIGN COMPONENT 'OPERACAO' OF STRUCTURE <f_w_bkg> TO <f_operacao>.
          CHECK <f_operacao> EQ l_operacao.

          LOOP AT t_parametros INTO w_parametro WHERE empresa   EQ w_credenciais-empresa
                                                  AND tabela_sf EQ w_tabelas-tabela_sf.

            w_request_data-key   = w_parametro-campo_sf.
            ASSIGN COMPONENT w_parametro-campo_sf OF STRUCTURE <f_w_bkg> TO <f_field>.
            w_request_data-value = <f_field>.
            APPEND w_request_data TO t_request_data.
            CLEAR w_request_data.
            UNASSIGN <f_field>.

          ENDLOOP.

          w_sfobject-entity = w_tabelas-tabela_sf.
          w_sfobject-data[] = t_request_data[].
          APPEND w_sfobject TO t_sfobject.

          UNASSIGN: <f_empresa>,
                    <f_operacao>.

          CLEAR: w_request_data,
                 t_request_data[].

        ENDLOOP.
*/

        IF l_operacao EQ 'I'.
*/ Efetua a operação INSERT com o XML criado no item anterior
          PERFORM zf_call_insert USING w_tabelas-tabela_sf
                                       w_credenciais
                                       t_sfobject.
*/
        ELSE.
*/ Efetua a operação UPDATE com o XML criado no item anterior
          PERFORM zf_call_update USING w_tabelas-tabela_sf
                                       w_credenciais
                                       t_sfobject.
*/
        ENDIF.

      ENDDO.

    ENDLOOP.

  ENDLOOP.

ENDFORM.                    " ZF_CALL_SFAPI_BKG

*&---------------------------------------------------------------------*
*&      Form  ZF_GET_DELTA
*&---------------------------------------------------------------------*
FORM zf_get_delta .



ENDFORM.                    " ZF_GET_DELTA

*&---------------------------------------------------------------------*
*&      Form  ZF_CRIA_TABELAS_INTERNAS
*&---------------------------------------------------------------------*
FORM zf_cria_tabelas_internas .

  DATA: w_dyn_fcat        TYPE lvc_s_fcat,
        t_dyn_fcat        TYPE lvc_t_fcat,
        t_param_loc       LIKE t_parametros,
        w_param_loc       LIKE LINE OF t_parametros,
        w_parametro       LIKE LINE OF t_parametros,
        l_o_new_type      TYPE REF TO cl_abap_structdescr,
        l_o_new_tab       TYPE REF TO cl_abap_tabledescr,
        t_comp            TYPE cl_abap_structdescr=>component_table,
        w_comp            LIKE LINE OF t_comp,
        t_table           TYPE REF TO data,
        l_table           TYPE string,
        l_count(2)        TYPE n.

  FIELD-SYMBOLS: <f_table> TYPE table.

  t_param_loc[] = t_parametros[].
  SORT t_param_loc BY tabela_sf.
  DELETE ADJACENT DUPLICATES FROM t_param_loc COMPARING tabela_sf.

  LOOP AT t_param_loc INTO w_param_loc.

    CLEAR: l_o_new_type,
           l_o_new_tab,
           t_comp.

    w_comp-name = 'EMPRESA'.
    w_comp-type = cl_abap_elemdescr=>get_string( ).
    APPEND w_comp TO t_comp.
    CLEAR: w_comp.

    w_comp-name = 'OPERACAO'.
    w_comp-type = cl_abap_elemdescr=>get_string( ).
    APPEND w_comp TO t_comp.
    CLEAR: w_comp.

    LOOP AT t_parametros INTO w_parametro WHERE tabela_sf EQ w_param_loc-tabela_sf.

      w_comp-name = w_parametro-campo_sf.
      w_comp-type = cl_abap_elemdescr=>get_string( ).
      APPEND w_comp TO t_comp.
      CLEAR: w_comp.

    ENDLOOP.

    l_o_new_type = cl_abap_structdescr=>create( t_comp ).
    l_o_new_tab = cl_abap_tabledescr=>create(
                    p_line_type  = l_o_new_type
                    p_table_kind = cl_abap_tabledescr=>tablekind_std
                    p_unique     = abap_false ).

    CREATE DATA t_table TYPE HANDLE l_o_new_tab.

    IF w_param_loc-tabela_sf EQ 'USER'.

      ASSIGN t_table->* TO <f_t_user>.
      w_tabelas-tabela_sf       = w_param_loc-tabela_sf.
      w_tabelas-tabela_interna  = '<F_T_USER>'.
      APPEND w_tabelas TO t_tabelas.

    ELSE.

      ADD 1 TO l_count.

      CASE l_count.
        WHEN '01'. ASSIGN t_table->* TO <f_t_01>.
        WHEN '02'. ASSIGN t_table->* TO <f_t_02>.
        WHEN '03'. ASSIGN t_table->* TO <f_t_03>.
        WHEN '04'. ASSIGN t_table->* TO <f_t_04>.
        WHEN '05'. ASSIGN t_table->* TO <f_t_05>.
        WHEN '06'. ASSIGN t_table->* TO <f_t_06>.
        WHEN '07'. ASSIGN t_table->* TO <f_t_07>.
        WHEN '08'. ASSIGN t_table->* TO <f_t_08>.
        WHEN '09'. ASSIGN t_table->* TO <f_t_09>.
        WHEN '10'. ASSIGN t_table->* TO <f_t_10>.
        WHEN '11'. ASSIGN t_table->* TO <f_t_11>.
        WHEN '12'. ASSIGN t_table->* TO <f_t_12>.
        WHEN '13'. ASSIGN t_table->* TO <f_t_13>.
        WHEN '14'. ASSIGN t_table->* TO <f_t_14>.
        WHEN '15'. ASSIGN t_table->* TO <f_t_15>.
        WHEN '16'. ASSIGN t_table->* TO <f_t_16>.
        WHEN '17'. ASSIGN t_table->* TO <f_t_17>.
        WHEN '18'. ASSIGN t_table->* TO <f_t_18>.
        WHEN '19'. ASSIGN t_table->* TO <f_t_19>.
        WHEN '20'. ASSIGN t_table->* TO <f_t_20>.
        WHEN OTHERS.
      ENDCASE.

      l_table = '<F_T_' && l_count && '>'.
      w_tabelas-tabela_sf       = w_param_loc-tabela_sf.
      w_tabelas-tabela_interna  = l_table.
      APPEND w_tabelas TO t_tabelas.

    ENDIF.

  ENDLOOP.

ENDFORM.                    " ZF_CRIA_TABELAS_INTERNAS

*&---------------------------------------------------------------------*
*&      Form  ZF_GRAVAR_LOG
*&---------------------------------------------------------------------*
FORM zf_gravar_log .

  DATA: t_param TYPE TABLE OF rsparams,
        w_param TYPE rsparams.

  MODIFY ztbhr_sfsf_log FROM TABLE t_log.

  w_param-kind    = 'S'.
  w_param-option  = 'EQ'.
  w_param-selname = 'S_IDLOG'.
  w_param-sign    = 'I'.
  w_param-low     = v_idlog.
  APPEND w_param TO t_param.
  CLEAR w_param.

  SUBMIT zglrhr0157_cockpit_log_factors WITH SELECTION-TABLE t_param.

ENDFORM.                    " ZF_GRAVAR_LOG

*&---------------------------------------------------------------------*
*&      Form  ZF_REG_INFTY
*&---------------------------------------------------------------------*
FORM zf_reg_infty  USING    p_parametro LIKE LINE OF t_parametros
                            p_workarea_sap
                   CHANGING p_infty.

  DATA: l_infty TYPE string.

  FIELD-SYMBOLS: <f_t_infty>     TYPE table,
                 <f_w_infty>     TYPE any,
                 <f_begda>       TYPE any,
                 <f_begda_ref>   TYPE any,
                 <f_endda>       TYPE any.

  ASSIGN COMPONENT 'BEGDA' OF STRUCTURE p_workarea_sap TO <f_begda_ref>.

  l_infty = 'P' && p_parametro-infty && '[]'.
  ASSIGN (l_infty) TO <f_t_infty>.
  IF sy-subrc NE 0. PERFORM zf_log USING space c_error 'Erro ao Associar Infotipo '(008) l_infty. ENDIF.

  CHECK <f_t_infty> IS ASSIGNED.

  LOOP AT <f_t_infty> ASSIGNING <f_w_infty>.

    ASSIGN COMPONENT 'BEGDA' OF STRUCTURE <f_w_infty> TO <f_begda>.
    ASSIGN COMPONENT 'ENDDA' OF STRUCTURE <f_w_infty> TO <f_endda>.

    IF <f_begda> LE <f_begda_ref> AND
       <f_endda> GE <f_begda_ref>.
      EXIT.
    ENDIF.

  ENDLOOP.

ENDFORM.                    " ZF_REG_INFTY

*&---------------------------------------------------------------------*
*&      Form  ZF_CALL_UPSERT
*&---------------------------------------------------------------------*
FORM zf_call_upsert  USING p_credenciais LIKE LINE OF t_credenciais
                           p_sfobject    TYPE zsfi_dt_operation_request__tab.

  DATA: l_count     TYPE i,
        l_count_tot TYPE i,
        l_lote      TYPE i,
        l_o_erro    TYPE REF TO cx_root,
        l_text      TYPE string,
        l_sessionid TYPE string,
        l_batchsize TYPE i,
        l_tabix     TYPE sy-tabix,
        l_o_upsert  TYPE REF TO zsfi_co_si_upsert_request,
        w_request   TYPE zsfi_mt_operation_request,
        w_response  TYPE zsfi_mt_operation_response,
        w_sfobject  TYPE LINE OF zsfi_dt_operation_request__tab,
        t_sfobject  TYPE zsfi_dt_operation_request__tab.

  l_count = lines( p_sfobject ) / p_credenciais-batchsize.

  DO l_count TIMES.

    LOOP AT p_sfobject INTO w_sfobject.

      l_tabix = sy-tabix.
      ADD 1 TO l_lote.
      ADD 1 TO l_count_tot.

      APPEND w_sfobject TO t_sfobject.
      DELETE p_sfobject INDEX l_tabix..
      CLEAR w_sfobject.

      IF l_lote     EQ p_credenciais-batchsize OR
         l_count_tot  EQ lines( p_sfobject ).

        PERFORM zf_login_successfactors USING p_credenciais-empresa
                                     CHANGING l_sessionid
                                              l_batchsize.

        TRY.

            CREATE OBJECT l_o_upsert.

            w_request-mt_operation_request-entity     = 'USER'.
            w_request-mt_operation_request-session_id = l_sessionid.
            w_request-mt_operation_request-sfobject   = t_sfobject.

            CALL METHOD l_o_upsert->si_upsert_request
              EXPORTING
                output = w_request
              IMPORTING
                input  = w_response.

          CATCH cx_ai_system_fault INTO l_o_erro.
            PERFORM zf_log USING space c_error 'Erro ao Efetuar Upsert para a Empresa'(015) p_credenciais-empresa.

            l_text = l_o_erro->get_text( ).
            PERFORM zf_log USING space c_error l_text space.

          CATCH cx_ai_application_fault INTO l_o_erro.
            PERFORM zf_log USING space c_error 'Erro ao Efetuar Upsert para a Empresa'(015) p_credenciais-empresa.

            l_text = l_o_erro->get_text( ).
            PERFORM zf_log USING space c_error l_text space.

        ENDTRY.

*/    Efetua o Logout no SuccessFactors.
        PERFORM zf_logout_successfactors CHANGING l_sessionid.
*/

        CLEAR: l_lote,
               w_sfobject,
               t_sfobject.

      ENDIF.

    ENDLOOP.

  ENDDO.

ENDFORM.                    " ZF_CALL_UPSERT

*&---------------------------------------------------------------------*
*&      Form  zf_call_INsert
*&---------------------------------------------------------------------*
FORM zf_call_insert  USING p_tabela_sf
                           p_credenciais LIKE LINE OF t_credenciais
                           p_sfobject    TYPE zsfi_dt_operation_request__tab.

  DATA: l_count     TYPE i,
        l_count_tot TYPE i,
        l_lote      TYPE i,
        l_o_erro    TYPE REF TO cx_root,
        l_text      TYPE string,
        l_sessionid TYPE string,
        l_batchsize TYPE i,
        l_tabix     TYPE sy-tabix,
        l_o_insert  TYPE REF TO zsfi_co_si_insert_request,
        w_request   TYPE zsfi_mt_operation_request,
        w_response  TYPE zsfi_mt_operation_response,
        w_sfobject  TYPE LINE OF zsfi_dt_operation_request__tab,
        t_sfobject  TYPE zsfi_dt_operation_request__tab.

  l_count = lines( p_sfobject ) / p_credenciais-batchsize.

  DO l_count TIMES.

    LOOP AT p_sfobject INTO w_sfobject.

      l_tabix = sy-tabix.
      ADD 1 TO l_lote.
      ADD 1 TO l_count_tot.

      APPEND w_sfobject TO t_sfobject.
      DELETE p_sfobject INDEX l_tabix.
      CLEAR w_sfobject.

      IF l_lote     EQ p_credenciais-batchsize OR
         l_count_tot  EQ lines( p_sfobject ).

        PERFORM zf_login_successfactors USING p_credenciais-empresa
                                     CHANGING l_sessionid
                                              l_batchsize.

        TRY.

            CREATE OBJECT l_o_insert.

            w_request-mt_operation_request-entity     = p_tabela_sf.
            w_request-mt_operation_request-session_id = l_sessionid.
            w_request-mt_operation_request-sfobject   = t_sfobject.

            CALL METHOD l_o_insert->si_insert_request
              EXPORTING
                output = w_request
              IMPORTING
                input  = w_response.

          CATCH cx_ai_system_fault INTO l_o_erro.
            PERFORM zf_log USING space c_error 'Erro ao Efetuar Insert para a Empresa'(018) p_credenciais-empresa.

            l_text = l_o_erro->get_text( ).
            PERFORM zf_log USING space c_error l_text space.

          CATCH cx_ai_application_fault INTO l_o_erro.
            PERFORM zf_log USING space c_error 'Erro ao Efetuar Insert para a Empresa' p_credenciais-empresa.

            l_text = l_o_erro->get_text( ).
            PERFORM zf_log USING space c_error l_text space.

        ENDTRY.

*/    Efetua o Logout no SuccessFactors.
        PERFORM zf_logout_successfactors CHANGING l_sessionid.
*/

        CLEAR: l_lote,
               w_sfobject,
               t_sfobject.

      ENDIF.

    ENDLOOP.

  ENDDO.

ENDFORM.                    " ZF_CALL_INSERT

*&---------------------------------------------------------------------*
*&      Form  zf_call_update
*&---------------------------------------------------------------------*
FORM zf_call_update  USING p_tabela_sf
                           p_credenciais LIKE LINE OF t_credenciais
                           p_sfobject    TYPE zsfi_dt_operation_request__tab.

  DATA: l_count     TYPE i,
        l_count_tot TYPE i,
        l_lote      TYPE i,
        l_o_erro    TYPE REF TO cx_root,
        l_text      TYPE string,
        l_sessionid TYPE string,
        l_batchsize TYPE i,
        l_tabix     TYPE sy-tabix,
        l_o_update  TYPE REF TO zsfi_co_si_update_request,
        w_request   TYPE zsfi_mt_operation_request,
        w_response  TYPE zsfi_mt_operation_response,
        w_sfobject  TYPE LINE OF zsfi_dt_operation_request__tab,
        t_sfobject  TYPE zsfi_dt_operation_request__tab.

  l_count = lines( p_sfobject ) / p_credenciais-batchsize.

  DO l_count TIMES.

    LOOP AT p_sfobject INTO w_sfobject.

      l_tabix = sy-tabix.
      ADD 1 TO l_lote.
      ADD 1 TO l_count_tot.

      APPEND w_sfobject TO t_sfobject.
      DELETE p_sfobject INDEX l_tabix..
      CLEAR w_sfobject.

      IF l_lote     EQ p_credenciais-batchsize OR
         l_count_tot  EQ lines( p_sfobject ).

        PERFORM zf_login_successfactors USING p_credenciais-empresa
                                     CHANGING l_sessionid
                                              l_batchsize.

        TRY.

            CREATE OBJECT l_o_update.

            w_request-mt_operation_request-entity     = p_tabela_sf.
            w_request-mt_operation_request-session_id = l_sessionid.
            w_request-mt_operation_request-sfobject   = t_sfobject.

            CALL METHOD l_o_update->si_update_request
              EXPORTING
                output = w_request
              IMPORTING
                input  = w_response.

          CATCH cx_ai_system_fault INTO l_o_erro.
            PERFORM zf_log USING space c_error 'Erro ao Efetuar Update para a Empresa'(019) p_credenciais-empresa.

            l_text = l_o_erro->get_text( ).
            PERFORM zf_log USING space c_error l_text space.

          CATCH cx_ai_application_fault INTO l_o_erro.
            PERFORM zf_log USING space c_error 'Erro ao Efetuar Update para a Empresa'(019) p_credenciais-empresa.

            l_text = l_o_erro->get_text( ).
            PERFORM zf_log USING space c_error l_text space.

        ENDTRY.

*/    Efetua o Logout no SuccessFactors.
        PERFORM zf_logout_successfactors CHANGING l_sessionid.
*/

        CLEAR: l_lote,
               w_sfobject,
               t_sfobject.

      ENDIF.

    ENDLOOP.

  ENDDO.

ENDFORM.                    " ZF_CALL_UPDATE