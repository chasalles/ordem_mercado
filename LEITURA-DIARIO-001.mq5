//+------------------------------------------------------------------+
//|                                                 TUTONACCI001.mq5 |
//|                        Copyright 2019, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\SymbolInfo.mqh> 
#include <Trade\Trade.mqh>

CTrade trade; 

ulong idOrdemCompra;
ulong idOrdemVenda;

MqlDateTime mqlDataAtual;
MqlDateTime mqlDataCandle;

MqlRates historicoPrecos[];

datetime dataAtual;
datetime dataInicio;

string InpFileNameMin;  // nome do arquivo
string InpFileNameMax;  // nome do arquivo
string InpFileNameClose;  // nome do arquivo

int handleMA07;
int handleMA21;
int handleMA50;
int handleMA200;
int handleSTD14;

double iMA07Buffer[]; 
double iMA21Buffer[];
double iMA50Buffer[];
double iMA200Buffer[];
double sTD14Buffer[];

int historico = 2000; 

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(){
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
   
    InpFileNameMin = _Symbol + "-DIARIO-MINIMO.csv";  // nome do arquivo
    InpFileNameMax = _Symbol + "-DIARIO-MAXIMO.csv";  // nome do arquivo
    InpFileNameClose = _Symbol + "-DIARIO-CLOSE.csv";  // nome do arquivo
   
    trade.SetExpertMagicNumber(891993);
    trade.SetTypeFilling(ORDER_FILLING_RETURN);
    trade.SetDeviationInPoints(10);
    trade.LogLevel(LOG_LEVEL_ERRORS);
    trade.SetAsyncMode(false); 
   
    //--- create timer
    EventSetTimer(3300);
    
    calculaLimites();
    
    //---
    return(INIT_SUCCEEDED);
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
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer(){
   dataAtual = TimeTradeServer();
   TimeToStruct(dataAtual, mqlDataAtual);
   
   if(mqlDataAtual.hour == 19){
      calculaLimites();
   }   
}

void calculaLimites(){
    handleMA07 = iMA(NULL, 0, 7, 0, MODE_EMA, PRICE_CLOSE);
    handleMA21 = iMA(NULL, 0, 21, 0, MODE_EMA, PRICE_CLOSE);
    handleMA50 = iMA(NULL, 0, 50, 0, MODE_EMA, PRICE_CLOSE);
    handleMA200 = iMA(NULL, 0, 200, 0, MODE_EMA, PRICE_CLOSE);
    handleSTD14 =iStdDev(NULL, PERIOD_D1, 14, 0, MODE_EMA, PRICE_CLOSE);
    
    SetIndexBuffer(0, iMA07Buffer, INDICATOR_DATA); 
    SetIndexBuffer(0, iMA21Buffer, INDICATOR_DATA); 
    SetIndexBuffer(0, iMA50Buffer, INDICATOR_DATA); 
    SetIndexBuffer(0, iMA200Buffer, INDICATOR_DATA); 
    SetIndexBuffer(0, sTD14Buffer, INDICATOR_DATA); 
    
    int numeroDeElementos = CopyRates(_Symbol, PERIOD_D1, 0, historico, historicoPrecos);
  
    int copied1 = CopyBuffer(handleMA07, 0, 0, historico, iMA07Buffer); 
    int copied2 = CopyBuffer(handleMA21, 0, 0, historico, iMA21Buffer);
    int copied3 = CopyBuffer(handleMA50, 0, 0, historico, iMA50Buffer); 
    int copied4 = CopyBuffer(handleMA200, 0, 0, historico, iMA200Buffer); 
    int copied5 = CopyBuffer(handleSTD14, 0, 0, historico, sTD14Buffer); 

    if(FileIsExist(InpFileNameMin)){
        FileDelete(InpFileNameMin);
        Print("Deletou o arquivo!");
    }
    
    if(FileIsExist(InpFileNameMax)){
        FileDelete(InpFileNameMax);
        Print("Deletou o arquivo!");
    }
    
    if(FileIsExist(InpFileNameClose)){
        FileDelete(InpFileNameClose);
        Print("Deletou o arquivo!");
    }
    
    int file_handle_min = FileOpen(InpFileNameMin, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
    int file_handle_max = FileOpen(InpFileNameMax, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
    int file_handle_close = FileOpen(InpFileNameClose, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
    
    if(file_handle_min != INVALID_HANDLE && file_handle_max != INVALID_HANDLE && file_handle_close != INVALID_HANDLE){
        PrintFormat("%s arquivo está disponível para ser escrito", InpFileNameMin);
        PrintFormat("%s arquivo está disponível para ser escrito", InpFileNameMax);
        PrintFormat("%s arquivo está disponível para ser escrito", InpFileNameClose);
        PrintFormat("Caminho do arquivo: %s\\Files\\", TerminalInfoString(TERMINAL_DATA_PATH));
        
        FileWrite(file_handle_min, "\"tempo\"", "\"diasemana\"", "\"abertura\"", "\"maxima\"", "\"minima\"", "\"fechamento\"", "\"volume\"", "\"media7\"",  "\"media21\"", "\"media50\"",  "\"media200\"", "\"desvio14\"", "\"previsao\"");
        FileWrite(file_handle_max, "\"tempo\"", "\"diasemana\"", "\"abertura\"", "\"maxima\"", "\"minima\"", "\"fechamento\"", "\"volume\"", "\"media7\"",  "\"media21\"", "\"media50\"",  "\"media200\"", "\"desvio14\"", "\"previsao\"");
        FileWrite(file_handle_close, "\"tempo\"", "\"diasemana\"", "\"abertura\"", "\"maxima\"", "\"minima\"", "\"fechamento\"", "\"volume\"", "\"media7\"",  "\"media21\"", "\"media50\"",  "\"media200\"", "\"desvio14\"", "\"previsao\"");
        
        int pula_desvios = 14;
        
        for(int i = pula_desvios; i < numeroDeElementos; i++){
            TimeToStruct(historicoPrecos[i].time, mqlDataCandle);
            
            string data_leitura = (string)mqlDataCandle.year + "-" + (string)mqlDataCandle.mon + "-" + (string)mqlDataCandle.day;
            string dia_semana = (string)mqlDataCandle.day_of_week;
            
            if(i == numeroDeElementos - 1){ 
               FileWrite(file_handle_min, data_leitura, dia_semana, historicoPrecos[i].open, historicoPrecos[i].high, historicoPrecos[i].low, historicoPrecos[i].close, historicoPrecos[i].real_volume, iMA07Buffer[i], iMA21Buffer[i], iMA50Buffer[i], iMA200Buffer[i], sTD14Buffer[i], historicoPrecos[i].low);
               FileWrite(file_handle_max, data_leitura, dia_semana, historicoPrecos[i].open, historicoPrecos[i].high, historicoPrecos[i].low, historicoPrecos[i].close, historicoPrecos[i].real_volume, iMA07Buffer[i], iMA21Buffer[i], iMA50Buffer[i], iMA200Buffer[i], sTD14Buffer[i], historicoPrecos[i].high);
               FileWrite(file_handle_close, data_leitura, dia_semana, historicoPrecos[i].open, historicoPrecos[i].high, historicoPrecos[i].low, historicoPrecos[i].close, historicoPrecos[i].real_volume, iMA07Buffer[i], iMA21Buffer[i], iMA50Buffer[i], iMA200Buffer[i], sTD14Buffer[i], historicoPrecos[i].close);
            }else{
               FileWrite(file_handle_min, data_leitura, dia_semana, historicoPrecos[i].open, historicoPrecos[i].high, historicoPrecos[i].low, historicoPrecos[i].close, historicoPrecos[i].real_volume, iMA07Buffer[i], iMA21Buffer[i], iMA50Buffer[i], iMA200Buffer[i], sTD14Buffer[i], historicoPrecos[i + 1].low);
               FileWrite(file_handle_max, data_leitura, dia_semana, historicoPrecos[i].open, historicoPrecos[i].high, historicoPrecos[i].low, historicoPrecos[i].close, historicoPrecos[i].real_volume, iMA07Buffer[i], iMA21Buffer[i], iMA50Buffer[i], iMA200Buffer[i], sTD14Buffer[i], historicoPrecos[i + 1].high);
               FileWrite(file_handle_close, data_leitura, dia_semana, historicoPrecos[i].open, historicoPrecos[i].high, historicoPrecos[i].low, historicoPrecos[i].close, historicoPrecos[i].real_volume, iMA07Buffer[i], iMA21Buffer[i], iMA50Buffer[i], iMA200Buffer[i], sTD14Buffer[i], historicoPrecos[i + 1].close);
            }  
        }
        
        //--- fechar o arquivo
        FileClose(file_handle_min);
        FileClose(file_handle_max);
        FileClose(file_handle_close);
        
        PrintFormat("Os dados são escritos, %s arquivo esta fechado");
     }
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
}
