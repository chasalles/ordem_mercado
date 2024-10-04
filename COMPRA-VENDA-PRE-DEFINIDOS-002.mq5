//+------------------------------------------------------------------+
//|                                                 TUTONACCI001.mq5 |
//|                        Copyright 2019, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\OrderInfo.mqh>
#include <Trade\SymbolInfo.mqh> 
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>


CTrade trade; 
CSymbolInfo simbolo;
COrderInfo orderInfo;
CPositionInfo positionInfo;

MqlRates historicoPrecos[];

MqlDateTime mqlDataPosicao;
MqlDateTime mqlDataAtual;

MqlTick last_tick;

datetime dataAtual;
datetime dataInicio;

double diario_maximo;
double diario_minimo;

double precoCompra;
double precoVenda;

input double inputLotes = 100;
input double inputGain = 0.36;
input double inputLoss = 0.18;
input bool inputEntrou = false;
double lotes = inputLotes;
double stopGain = inputGain;
double stopLoss = inputLoss;
bool entrou = inputEntrou;

ulong idOrdemCompra;
ulong idOrdemVenda;

ulong idOrdemCompraLoss;
ulong idOrdemVendaLoss;

int ordersTotal;
int positionTotal;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(){
    
    informacoesConta();
   
    // Ajuste iniciais dos trades
    trade.SetExpertMagicNumber(891993);
    trade.SetTypeFilling(ORDER_FILLING_RETURN);
    trade.SetDeviationInPoints(10);
    trade.LogLevel(LOG_LEVEL_ERRORS);
    trade.SetAsyncMode(false); 
    
    ArraySetAsSeries(historicoPrecos, true);
    
    //abreVariasOrdens();
    
    inicializa();
    imprime();
    
    //--- create timer
    EventSetTimer(3600);
   
    //---
    return(INIT_SUCCEEDED);
}

void informacoesConta(){
    //--- Nome da empresa 
    string company = AccountInfoString(ACCOUNT_COMPANY);
   
    //--- Nome do cliente 
    string name = AccountInfoString(ACCOUNT_NAME); 
   
    //--- Número da conta 
    long login = AccountInfoInteger(ACCOUNT_LOGIN);

    //--- Nome do servidor 
    string server = AccountInfoString(ACCOUNT_SERVER); 
   
    //--- Moeda da conta 
    string currency = AccountInfoString(ACCOUNT_CURRENCY); 
   
    //--- Conta demo, de torneio ou real 
    ENUM_ACCOUNT_TRADE_MODE account_type =(ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE); 

    //--- Agora transforma o valor da enumeração em uma forma inteligível 
    string trade_mode = "";
   
    switch(account_type){ 
        case ACCOUNT_TRADE_MODE_DEMO: 
            trade_mode = "demo"; 
            break; 
        case ACCOUNT_TRADE_MODE_CONTEST: 
            trade_mode = "concurso"; 
            break; 
        default: 
            trade_mode = "real"; 
            break; 
    }
     
    //--- Stop Out é definida em percentagem ou dinheiro 
    ENUM_ACCOUNT_STOPOUT_MODE stop_out_mode = (ENUM_ACCOUNT_STOPOUT_MODE)AccountInfoInteger(ACCOUNT_MARGIN_SO_MODE);
    
    //--- Obtém os valores dos níveis quando a Chamada de Margem e Stop Out (encerramento forçado) ocorrem 
    double margin_call = AccountInfoDouble(ACCOUNT_MARGIN_SO_CALL); 
   
    double stop_out = AccountInfoDouble(ACCOUNT_MARGIN_SO_SO); 
   
    //--- Exibe informações resumidas sobre a conta 
    PrintFormat("A conta do do cliente '%s' #%d %s aberta em '%s' no servidor '%s'", name, login, trade_mode, company, server); 
    PrintFormat("Moeda da conta - %s, níveis de MarginCall e StopOut são configurados em %s", currency,(stop_out_mode == ACCOUNT_STOPOUT_MODE_PERCENT)? "porcentagem" : " dinheiro"); 
    PrintFormat("MarginCall = %G, StopOut = %G", margin_call, stop_out); 
    Print("Número permitido máximo de ordens pendentes ativas: ", AccountInfoInteger(ACCOUNT_LIMIT_ORDERS));
    Print("Saldo da conta na moeda de depósito: ", AccountInfoDouble(ACCOUNT_BALANCE));
    Print("Lucro atual de uma conta na moeda de depósito: ", AccountInfoDouble(ACCOUNT_PROFIT));
}

// Rotina para teste
void abreVariasOrdens(){
    for(int i = 0; i < 10; ++i){
        trade.OrderOpen(_Symbol, ORDER_TYPE_BUY_LIMIT, 100, NULL, 20, NULL, NULL, ORDER_TIME_GTC, 0, NULL);
        trade.OrderDelete(trade.ResultOrder());
    }
}

// Faz leitura do arquivo obtendo a minima e a maxima
void inicializa(){
   diario_maximo = 0;
   diario_minimo = 0;  
   //diario_minimo = 39.35;
   //diario_maximo = 39.85;
    
   leituraArquivo();

   precoCompra = diario_minimo;
   precoVenda = diario_maximo;
    
   lotes = inputLotes;
   //lotes = 1600;
}

void leituraArquivo(){
    int filehandle_minima = FileOpen("mediana_minima.txt", FILE_TXT|FILE_READ|FILE_ANSI);
    
    if(filehandle_minima != INVALID_HANDLE) {
        diario_minimo = StringToDouble(FileReadString(filehandle_minima, -1));
        FileClose(filehandle_minima);
        Print("*** FILE MINIMA OK");    
    }else{
        Print("*** FILE MINIMA ERRO"); 
    }
    
    int filehandle_maxima = FileOpen("mediana_maxima.txt", FILE_TXT|FILE_READ|FILE_ANSI);
    
    if(filehandle_maxima != INVALID_HANDLE) {
        diario_maximo =  StringToDouble(FileReadString(filehandle_maxima, -1));
        FileClose(filehandle_maxima);
        Print("*** FILE MAXIMA OK");
    }else{
        Print("*** FILE MAXIMA ERRO");
    }
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){
    //--- destroy timer
    EventKillTimer(); 
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){   
    dataAtual = TimeTradeServer();
    TimeToStruct(dataAtual, mqlDataAtual);
    
    simbolo.Refresh();
    simbolo.RefreshRates();

    // Verificar se está no leilão
    
    SymbolInfoTick(_Symbol, last_tick);
    
    if(mqlDataAtual.hour < 10){
        if(last_tick.bid > last_tick.ask){
            Print("Pré-abertura / Leilão");
            Print(last_tick.time,": Bid = ", last_tick.bid, " Ask = ", last_tick.ask,"  Volume = ", last_tick.volume);
            return;
        }
    }
    // Fim verifica leilão
    
    CopyRates(_Symbol, PERIOD_D1, 0, 10, historicoPrecos);
    
    ordersTotal = OrdersTotal();
    positionTotal = PositionsTotal();
    
    if(mqlDataAtual.hour >= 10 && mqlDataAtual.hour <= 11){
        if(positionTotal == 0){
            if(ordersTotal == 0){
                if(entrou){
                    // Abertura de ordem ou posicao
                    aberturaDeOrdemPosicao();
                    entrou = false;
                    imprime();
                }
            }
        }
    }else{
        // Encerra ordens e posicoes depois do horário
        if(mqlDataAtual.hour >= 12 && mqlDataAtual.hour <= 16){
            encerraOrdens();
        }else{
            if(mqlDataAtual.hour == 17){
                encerraPositions();
            }
        }
    }
}

void aberturaDeOrdemPosicao(){
    Print("------VOLUME DO TICK: ", last_tick.volume_real);
    
    // Entre o máximo e o mínimo
    if(diario_minimo < historicoPrecos[0].open || diario_maximo > historicoPrecos[0].open){
        entreMaximoMinimo();
    }
}

void entreMaximoMinimo(){
   if(diario_minimo < historicoPrecos[0].open){
      if(trade.OrderOpen(_Symbol, ORDER_TYPE_BUY_LIMIT, lotes, NULL, precoCompra, precoCompra - stopLoss, precoCompra + stopGain, ORDER_TIME_GTC, 0, "ORDEM: COMPRA EM " + (string)precoCompra)){
         idOrdemCompra = trade.ResultOrder();
         Print("----------------------------------------------");
         Print("CÓDIGO ORDEM DE COMPRA: ", trade.ResultRetcode());
         Print("----------------------------------------------");
      }else{
         Print("##### ERRO NÃO POSICIONOU ORDEM DE COMPRA: ", trade.ResultRetcode());
      }                                
   }else{
      Print("##### VALOR ABERTURA ABAIXO DO MÍNIMO");
   }
    
    if(diario_maximo > historicoPrecos[0].open){
      if(trade.OrderOpen(_Symbol, ORDER_TYPE_SELL_LIMIT, lotes, NULL, precoVenda, precoVenda + stopLoss, precoVenda - stopGain, ORDER_TIME_GTC, 0, "ORDEM: VENDA EM " + (string)precoVenda)){
         idOrdemVenda = trade.ResultOrder();
         Print("----------------------------------------------");
         Print("CÓDIGO ORDEM DE VENDA: ", trade.ResultRetcode());
         Print("----------------------------------------------");
      }else{
         Print("##### NÃO POSICIONOU ORDEM DE VENDA: ", trade.ResultRetcode());
      } 
   }else{
      Print("##### VALOR ABERTURA ACIMA DO MÁXIMO");
   }
}

void ajusteStopLossZeroAZero(){
    positionTotal = PositionsTotal();
       
    ulong positionTicket;
    
    for(int i = 0; i < positionTotal; i++){ 
        positionTicket = PositionGetTicket(i);
            
        positionInfo.SelectByTicket(positionTicket);
            
        if(positionInfo.PositionType() == POSITION_TYPE_BUY){
            if(positionInfo.StopLoss() != precoCompra){
               ajusteCompra(positionTicket);
            }
        }else{
            // Se for uma ordem de venda
            if(positionInfo.StopLoss() != precoVenda){
               ajusteVenda(positionTicket);
            }
        } 
    }
}

void ajusteCompra(ulong positionTicket){
    // Metade da meta atingida
    if(simbolo.Last() > precoCompra + stopLoss){
        Print("----------------------------------------------"); 
        if(trade.PositionModify(positionTicket, precoCompra, precoCompra + stopGain)){
            Print("********STOP LOSS DA COMPRA MODIFICADA: ", trade.ResultRetcode());
        }else{
            Print("********ERRO - MODIFICAR STOP LOSS DA COMPRA: ", trade.ResultRetcode());
        }    
    }
}

void ajusteVenda(ulong positionTicket){
    // Metade da meta atingida
    if(simbolo.Last() < precoVenda - stopLoss){
        Print("----------------------------------------------");
        if(trade.PositionModify(positionTicket, precoVenda, precoVenda - stopGain)){
            Print("********STOP LOSS DA VENDA MODIFICADA: ", trade.ResultRetcode());
        }else{
            Print("********ERRO - MODIFICAR STOP LOSS DA COMPRA: ", trade.ResultRetcode());
        }    
    }
}

void encerraOrdens(){
   if(ordersTotal > 0){
      Print("######### ENCERRANDO ORDENS ABERTAS #########");
                
      ulong order_ticket;
    
      for(int i = 0; i < ordersTotal; i++){ 
         if((order_ticket = OrderGetTicket(i)) > 0){
            Print("######### ORDEM DELETADA: ", order_ticket);
            trade.OrderDelete(order_ticket);
         }
      }
   }
}

void encerraPositions(){       
   if(positionTotal > 0){
         Print("######### ENCERRANDO POSIÇÕES ABERTAS #########");
         trade.PositionClose(_Symbol, ULONG_MAX);
   }
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer(){
    dataAtual = TimeTradeServer();
    TimeToStruct(dataAtual, mqlDataAtual);
    
    if(mqlDataAtual.hour == 9){
        inicializa();
        imprime();
    }
}

void imprime(){
    Print("--------------------------------------");
    Print("*****************ENTROU: ", entrou);
    Print("*****************LOTES: ", lotes);
    Print("*****************MÁXIMO: ", diario_maximo);
    Print("*****************MÍNIMO: ", diario_minimo);
    Print("*****************MARGEM GAIN: ", stopGain);
    Print("*****************MARGEM LOSS: ", stopLoss);
    Print("--------------------------------------");
}

//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade(){
}

//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans, const MqlTradeRequest& request, const MqlTradeResult& result){
    if(trans.deal > 0 && trans.order == idOrdemCompra && trans.position == idOrdemCompra){
        Print("--------------------------COMPRA----ENTRADA-------------------------------------");
        Print("Trans - Bilhetagem da operação (deal): ", trans.deal); 
        Print("Trans - Bilhetagem da ordem: ", trans.order);  
        Print("Trans - Nome do ativo da negociação: ", trans.symbol);
        Print("Trans - Tipo de transação da negociação: ", trans.type); 
        Print("Trans - Tipo de ordem: ", trans.order_type);  
        Print("Trans - Estado da ordem: ", trans.order_state);  
        Print("Trans - Tipo de operação (deal): ", trans.deal_type); 
        Print("Trans - Tipo de ordem por período de ação: ", trans.time_type); 
        Print("Trans - Hora de expiração da ordem: ", trans.time_expiration); 
        Print("Trans - Preço: ", trans.price);  
        Print("Trans - Preço de ativação de ordem tipo Stop limit: ", trans.price_trigger);  
        Print("Trans - Nível de Stop Loss: ", trans.price_sl);  
        Print("Trans - Nível de Take Profit: ", trans.price_tp);  
        Print("Trans - Volume em lotes: ", trans.volume); 
        Print("Trans - Position ticket: ", trans.position);  
        Print("Trans - Ticket of an opposite position: ", trans.position_by);
        deleteOrdemPendente();
    }

    if(trans.deal > 0 && trans.order != idOrdemCompra && trans.position == idOrdemCompra){
        Print("--------------------------COMPRA----SAIDA-------------------------------------");
        Print("Trans - Bilhetagem da operação (deal): ", trans.deal); 
        Print("Trans - Bilhetagem da ordem: ", trans.order);  
        Print("Trans - Nome do ativo da negociação: ", trans.symbol);
        Print("Trans - Tipo de transação da negociação: ", trans.type); 
        Print("Trans - Tipo de ordem: ", trans.order_type);  
        Print("Trans - Estado da ordem: ", trans.order_state);  
        Print("Trans - Tipo de operação (deal): ", trans.deal_type); 
        Print("Trans - Tipo de ordem por período de ação: ", trans.time_type); 
        Print("Trans - Hora de expiração da ordem: ", trans.time_expiration); 
        Print("Trans - Preço: ", trans.price);  
        Print("Trans - Preço de ativação de ordem tipo Stop limit: ", trans.price_trigger);  
        Print("Trans - Nível de Stop Loss: ", trans.price_sl);  
        Print("Trans - Nível de Take Profit: ", trans.price_tp);  
        Print("Trans - Volume em lotes: ", trans.volume); 
        Print("Trans - Position ticket: ", trans.position);  
        Print("Trans - Ticket of an opposite position: ", trans.position_by);
        Print("--------------------------------------------------------------------------------");
        
        deleteOrdemPendente();
        
        imprime();
        Print("***************SAIU********************"); 
    }
    
    if(trans.deal > 0 && trans.order == idOrdemVenda && trans.position == idOrdemVenda){
        Print("--------------------------VENDA----ENTRADA-------------------------------------");
        Print("Trans - Bilhetagem da operação (deal): ", trans.deal); 
        Print("Trans - Bilhetagem da ordem: ", trans.order);  
        Print("Trans - Nome do ativo da negociação: ", trans.symbol);
        Print("Trans - Tipo de transação da negociação: ", trans.type); 
        Print("Trans - Tipo de ordem: ", trans.order_type);  
        Print("Trans - Estado da ordem: ", trans.order_state);  
        Print("Trans - Tipo de operação (deal): ", trans.deal_type); 
        Print("Trans - Tipo de ordem por período de ação: ", trans.time_type); 
        Print("Trans - Hora de expiração da ordem: ", trans.time_expiration); 
        Print("Trans - Preço: ", trans.price);  
        Print("Trans - Preço de ativação de ordem tipo Stop limit: ", trans.price_trigger);  
        Print("Trans - Nível de Stop Loss: ", trans.price_sl);  
        Print("Trans - Nível de Take Profit: ", trans.price_tp);  
        Print("Trans - Volume em lotes: ", trans.volume); 
        Print("Trans - Position ticket: ", trans.position);  
        Print("Trans - Ticket of an opposite position: ", trans.position_by);
        deleteOrdemPendente();
    }
    
    if(trans.deal > 0 && trans.order != idOrdemVenda && trans.position == idOrdemVenda){
        Print("--------------------------VENDA----SAIDA-------------------------------------");
        Print("Trans - Bilhetagem da operação (deal): ", trans.deal); 
        Print("Trans - Bilhetagem da ordem: ", trans.order);  
        Print("Trans - Nome do ativo da negociação: ", trans.symbol);
        Print("Trans - Tipo de transação da negociação: ", trans.type); 
        Print("Trans - Tipo de ordem: ", trans.order_type);  
        Print("Trans - Estado da ordem: ", trans.order_state);  
        Print("Trans - Tipo de operação (deal): ", trans.deal_type); 
        Print("Trans - Tipo de ordem por período de ação: ", trans.time_type); 
        Print("Trans - Hora de expiração da ordem: ", trans.time_expiration); 
        Print("Trans - Preço: ", trans.price);  
        Print("Trans - Preço de ativação de ordem tipo Stop limit: ", trans.price_trigger);  
        Print("Trans - Nível de Stop Loss: ", trans.price_sl);  
        Print("Trans - Nível de Take Profit: ", trans.price_tp);  
        Print("Trans - Volume em lotes: ", trans.volume); 
        Print("Trans - Position ticket: ", trans.position);  
        Print("Trans - Ticket of an opposite position: ", trans.position_by);
        Print("--------------------------------------------------------------------------------");

        deleteOrdemPendente();
        
        imprime();
        Print("***************SAIU********************"); 
    }
}

void deleteOrdemPendente(){
   int total = OrdersTotal();
   
   for(int i = 0; i < total; i++){
      ulong ticket = OrderGetTicket(i);
      
      if(ticket != 0){
         Print("------------------------------");
         // delete the pending order
         if(trade.OrderDelete(ticket)){
            Print("Ordens Pendentes: Foram excluídas.");
         }else{
            Print("Ordens Pendentes: NÃO FORAM excluídas.");
            Print("********* EXCLUÍNDO NOVAMENTE");
            deleteOrdemPendente();
         }
         Print("##### RETCODE EXCLUSÃO DE ORDENS: ", trade.ResultRetcode());
      }
   }
}

void imprimeOrdens(){
    int total = OrdersTotal();
   
    for(int i = 0; i < total; i++){
        ulong ticket = OrderGetTicket(i);
      
        if(ticket != 0){
            string type = EnumToString(ENUM_ORDER_TYPE(OrderGetInteger(ORDER_TYPE)));
            double open_price = OrderGetDouble(ORDER_PRICE_OPEN);
            double preco_corrente = OrderGetDouble(ORDER_PRICE_CURRENT);
            double volume_inicial = OrderGetDouble(ORDER_VOLUME_INITIAL);
            double volume_corrente = OrderGetDouble(ORDER_VOLUME_CURRENT);
            
            Print("-------------------------------------------------------");
            Print("......... Tipo de ordem: ", type);
            Print("......... Preço especificado na ordem: ", open_price);
            Print("......... O preço corrente do ativo de uma ordem: ", preco_corrente);
            Print("......... Volume inicial de uma ordem: ", volume_inicial);
            Print("......... Volume corrente de uma ordem: ", volume_corrente);
            Print("-------------------------------------------------------");
      }
   }
}