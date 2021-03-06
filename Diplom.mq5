//+------------------------------------------------------------------+
//|                                                       Diplom.mq5 |
//|                                   Copyright © 2020, Dmitry Ezhov |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2020, Dmitry Ezhov"
#property link      ""
#property version   "1.000"
#property description "Diplom"
//---
#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>  
#include <Expert\Money\MoneyFixedMargin.mqh>
CPositionInfo  m_position;                   
CTrade         m_trade;                      
CSymbolInfo    m_symbol;                     
CAccountInfo   m_account;                    
CMoneyFixedMargin  m_money;

enum modee
{Info,Semiauto,Auto,};

input double               InpRisk              = 5;                    //Риск в процентах
input uchar                InpShift             = 1;                    //Смещение в барах (от 1 до 255)
input ushort               InpDistance          = 0;                    //Расстояние в пипсах
input ulong                m_magic              = 727;                  //magic number
input modee                Work_Mode            = Auto;                 //Режим работы: 1 - Информационный, 2 - Полуавто, 3 - Авто
input double               StopLossPips         = 200;                  //StopLoss в пипсах
input double               TakeProfitPips       = 400;                  //TakeProfit в пипсах

ulong                      m_slippage=30;                               //Проскальзывание
double                     ExtDistance=0.0;
double                     m_lots_min=0.0;
double                     m_adjusted_point;                            //Для форматирования котировок
double                     Bid;                                         //Цена Бид
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpShift<1)
     {
      Print("Shift не может быть меньше единицы!");
      return(INIT_PARAMETERS_INCORRECT);
     }
     
   if(StopLossPips<0 || TakeProfitPips<0 || (StopLossPips<0 && TakeProfitPips<0) )
     {
      Print("StopLoss или TakeProfit не могут быть меньше нуля!");
      return(INIT_PARAMETERS_INCORRECT);
     }
     
   if(InpRisk<0)
     {
      Print("Риск не может быть меньше нуля!");
      return(INIT_PARAMETERS_INCORRECT);
     }

   m_symbol.Name(Symbol()); //Установка имени символа
   RefreshRates();
   m_symbol.Refresh();

   m_lots_min=m_symbol.LotsMin();

   m_trade.SetExpertMagicNumber(m_magic);

   if(IsFillingTypeAllowed(Symbol(),SYMBOL_FILLING_FOK))
      m_trade.SetTypeFilling(ORDER_FILLING_FOK);
   else if(IsFillingTypeAllowed(Symbol(),SYMBOL_FILLING_IOC))
      m_trade.SetTypeFilling(ORDER_FILLING_IOC);
   else
      m_trade.SetTypeFilling(ORDER_FILLING_RETURN);

   m_trade.SetDeviationInPoints(m_slippage);
   
   int digits_adjust=1;
   if(m_symbol.Digits()==3 || m_symbol.Digits()==5)
      digits_adjust=10;
   m_adjusted_point=m_symbol.Point()*digits_adjust;

   ExtDistance=InpDistance *m_adjusted_point;

   if(!m_money.Init(GetPointer(m_symbol),Period(),m_symbol.Point()*digits_adjust))
      return(INIT_FAILED);
   m_money.Percent(InpRisk);

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {


  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   static datetime PrevBars=0;
   datetime time_0=iTime(m_symbol.Name(),Period(),0);
   if(time_0==PrevBars) //iTime возвращает 0 в случае ошибки
      return;
   PrevBars=time_0;
   
   double m_sl;
   double m_tp;
//Получение котировок
   MqlRates rates[];
   ArraySetAsSeries(rates,true); // true -> rates[0] - последний бар
   int start_pos=InpShift;
   int copied=CopyRates(m_symbol.Name(),Period(),start_pos,2,rates);
   if(copied==2)
     {
      //Бычье поглощение
  /*    if(rates[0].open<rates[0].close) //Бар с индексом 0 - бычий
        {
         if(rates[1].open>rates[1].close) //Бар с индексом 1 - медвежий
           {
            if(rates[0].high>rates[1].high+ExtDistance &&
               rates[0].close>rates[1].open+ExtDistance &&
               rates[0].open<rates[1].close-ExtDistance &&
               rates[0].low<rates[1].low-ExtDistance)
              {  */
              
                 Bid = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_BID),_Digits);
                 m_tp = Bid + TakeProfitPips*Point();
                 m_sl = Bid - StopLossPips*Point();
                 
              if (Work_Mode == Info) {
              Alert("Рекомендуется покупать по цене: ", Bid, " СтопЛосс: ", m_sl, " ТейкПрофит: ", m_tp);
              } else {
              
               if(!RefreshRates())
                 {
                  PrevBars=iTime(m_symbol.Name(),Period(),1);
                  return;
                 }
                 //Print("bid:", Bid, " sl:", m_sl," tp:", m_tp," point:", Point());
                 if (Work_Mode == Auto) {
                 ClosePositions(POSITION_TYPE_SELL);
                 OpenBuy(m_sl,m_tp);
                 }
                 
                 if (Work_Mode == Semiauto) {
                 int place = MessageBox("Отправить ордер Buy?","Подтверждение",MB_YESNO);
                 if(place == IDYES) {
                 ClosePositions(POSITION_TYPE_SELL);
                 OpenBuy(m_sl,m_tp);
                 }
                    }
                 } 
           //   }
         //  }
       // }
      //Медвежье поглощение
  /*    else if(rates[0].open>rates[0].close) //Бар с индексом 0 - медвежий
        {
         if(rates[1].open<rates[1].close) //Бар с индексом 1 - бычий
           {
            if(rates[0].high>rates[1].high+ExtDistance &&
               rates[0].close<rates[1].open-ExtDistance &&
               rates[0].open>rates[1].close+ExtDistance &&
               rates[0].low<rates[1].low-ExtDistance)
              {
              
                 Bid = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_BID),_Digits);
                 m_tp = Bid - TakeProfitPips*Point();
                 m_sl = Bid + StopLossPips*Point();
                 
              if (Work_Mode == Info) {
              Alert("Рекомендуется продавать по цене: ", Bid, " СтопЛосс: ", m_sl, " ТейкПрофит: ", m_tp);
              }
              
               if(!RefreshRates())
                 {
                  PrevBars=iTime(m_symbol.Name(),Period(),1);
                  return;
                 }
                 //Print("bid:", Bid, " sl:", m_sl," tp:", m_tp," point:", Point());
                 if (Work_Mode == Auto) {
                 ClosePositions(POSITION_TYPE_BUY);
                 OpenSell(m_sl,m_tp);
                 }
                 
                 if (Work_Mode == Semiauto) {
                 int place = MessageBox("Отправить ордер Sell?","Подтверждение",MB_YESNO);
                 if(place == IDYES) {
                 ClosePositions(POSITION_TYPE_BUY);
                 OpenSell(m_sl,m_tp);
                 }
                 }
              }
           }
        } */
     }
   else
     {
      PrevBars=iTime(m_symbol.Name(),Period(),1);
      Print("Failed to get history data for the symbol ",Symbol());
     }
   return;
  }
//+------------------------------------------------------------------+
//| Refreshes the symbol quotes data                                 |
//+------------------------------------------------------------------+
bool RefreshRates()
  {
//Обновить данные
   if(!m_symbol.RefreshRates())
      return(false);
//Защита от возвращения значения 0
   if(m_symbol.Ask()==0 || m_symbol.Bid()==0)
      return(false);
   return(true);
  }
//+------------------------------------------------------------------+ 
//| Checks if the specified filling mode is allowed                  | 
//+------------------------------------------------------------------+ 
bool IsFillingTypeAllowed(string symbol,int fill_type)
  {
//Получить значение свойства, которое описывает разрешенные режимы заполнения ордера
   int filling=(int)SymbolInfoInteger(symbol,SYMBOL_FILLING_MODE);
//Возвращает true, если режим fill_type разрешен 
   return((filling & fill_type)==fill_type);
  }
//+------------------------------------------------------------------+
//| Close Positions                                                  |
//+------------------------------------------------------------------+
void ClosePositions(ENUM_POSITION_TYPE pos_type)
  {
   for(int i=PositionsTotal()-1;i>=0;i--) //Возвращает количество текущих ордеров
      if(m_position.SelectByIndex(i))     //Выбирает позицию по индексу для доступа к свойствам
         if(m_position.Symbol()==m_symbol.Name() && m_position.Magic()==m_magic)
            if(m_position.PositionType()==pos_type) //Получает тип позиции
               m_trade.PositionClose(m_position.Ticket()); //Закрыть позицию по выбранному символу
  }
//+------------------------------------------------------------------+
//| Open Buy position                                                |
//+------------------------------------------------------------------+
void OpenBuy(double sl,double tp)
  {
   sl=m_symbol.NormalizePrice(sl);
   tp=m_symbol.NormalizePrice(tp);

   double check_open_long_lot=m_money.CheckOpenLong(m_symbol.Ask(),sl);

   if(check_open_long_lot==0.0)
      return;

//Проверить объем перед отправкой ордера чтобы избежать ошибку с недостатком денег (CTrade)
   double check_volume_lot=m_trade.CheckVolume(m_symbol.Name(),check_open_long_lot,m_symbol.Ask(),ORDER_TYPE_BUY);

   if(check_volume_lot!=0.0)
      if(check_volume_lot>=check_open_long_lot)
        {
         if(m_trade.Buy(check_open_long_lot,NULL,m_symbol.Ask(),sl,tp))
           {
            if(m_trade.ResultDeal()==0)
              {
               Print("Buy -> false. Result Retcode: ",m_trade.ResultRetcode(),
                     ", description of result: ",m_trade.ResultRetcodeDescription());
              }
            else
              {
               Print("Buy -> true. Result Retcode: ",m_trade.ResultRetcode(),
                     ", description of result: ",m_trade.ResultRetcodeDescription());
              }
           }
         else
           {
            Print("Buy -> false. Result Retcode: ",m_trade.ResultRetcode(),
                  ", description of result: ",m_trade.ResultRetcodeDescription());
           }
        }
  }
//+------------------------------------------------------------------+
//| Open Sell position                                               |
//+------------------------------------------------------------------+
void OpenSell(double sl,double tp)
  {
   sl=m_symbol.NormalizePrice(sl);
   tp=m_symbol.NormalizePrice(tp);

   double check_open_short_lot=m_money.CheckOpenShort(m_symbol.Bid(),sl);

   if(check_open_short_lot==0.0)
      return;

//Проверить объем перед отправкой ордера чтобы избежать ошибку с недостатком денег (CTrade)
   double check_volume_lot=m_trade.CheckVolume(m_symbol.Name(),check_open_short_lot,m_symbol.Bid(),ORDER_TYPE_SELL);

   if(check_volume_lot!=0.0)
      if(check_volume_lot>=check_open_short_lot)
        {
         if(m_trade.Sell(check_open_short_lot,NULL,m_symbol.Bid(),sl,tp))
           {
            if(m_trade.ResultDeal()==0)
              {
               Print("Sell -> false. Result Retcode: ",m_trade.ResultRetcode(),
                     ", description of result: ",m_trade.ResultRetcodeDescription());
              }
            else
              {
               Print("Sell -> true. Result Retcode: ",m_trade.ResultRetcode(),
                     ", description of result: ",m_trade.ResultRetcodeDescription());
              }
           }
         else
           {
            Print("Sell -> false. Result Retcode: ",m_trade.ResultRetcode(),
                  ", description of result: ",m_trade.ResultRetcodeDescription());
           }
        }
  }