//+------------------------------------------------------------------+
//|                           FundamentalPrime_SampleExperts_RSI.mq4 |
//|                                                        Ver.1.000 |
//|                                     Fundamental Prime , SIA Inc. |
//|                                      https://www.funda-prime.com |
//+------------------------------------------------------------------+
//
// 当ソースファイルは MT4のMQL4を利用したプログラミングを使い、Fundamental Prime Web API へ
// アクセスする歳の、参考ソースとして用意いたしました。
// プログラミングの一助となれば幸いです。
// 十分な確認のうえご利用ください。
// 当ソースファルの利用に起因するすべての障害・損害の責任は負いかねますのでご理解の上ご利用ください。
// 不具合がありましたらお知らせいただければと存じます。
//
// RSI をトリガーとして利用していますが、Web API 参考のためのソースであり、成績を求めたものではないことご了承ください。
//
//
#property copyright "Fundamental Prime , SIA Inc."
#property description "Sample Program One"
#property version   "1.000"
#property link      "https://www.funda-prime.com"
#property strict

#include <FundamentalPrime1130.mqh>

#define MagicNumber  20201001

// このパラメータは EURUSD M5 2019/01/01～2020/09/20 向けの確認用パラメータ
input double Lots  = 1.0;
input int    RSI_Period = 14;
input int    RSI_Shift = 1;
input int    RSI_Top = 70;
input int    RSI_Bottom = 30;

input int STOP_FROM = 240;       // 経済指標N分前から新規ポジションを持たない
input int STOP_TO = 360;         // 経済指標N分後まで新規ポジションを持たない
input int STOP_IMPORTANCE = 1;   //０:すべての重要度 / 1:重要度1以上 / 2:重要度2以上 / 3:重要度3以上

//+------------------------------------------------------------------+
int OnInit()
  {
   string returnMessage = "";
   if(!FP_CHECK_ENVIRONMENT(returnMessage))
     {
      Alert(returnMessage);
      Print(returnMessage);
      return(INIT_FAILED);
     }

   FP_VIX_INITIALIZE();

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Check for open order conditions                                  |
//+------------------------------------------------------------------+
void CheckForOpen()
  {
   if(Volume[0] > 1)
      return;

   int    res;
   bool wantsCancel = false;
   double rsi = iRSI(NULL,0,RSI_Period,PRICE_CLOSE,RSI_Shift);

   string debugStr = "Server Time=" + TimeToStr(Time[0],TIME_DATE | TIME_SECONDS) + "\n";
   debugStr += "Server GMT Time=" + TimeToStr(DateConvertServer2API(Time[0]),TIME_DATE | TIME_SECONDS) + "\n\n";
   Print(debugStr);

//
// トレードチャンスと仮定
//
   if(rsi >= RSI_Top || rsi <= RSI_Bottom)
     {

      // 足に丸める
      datetime targetDatetime = (datetime)MathFloor((long)Time[0] / (60 * Period())) * (60 * Period());
      string returnMessage = "";

      if(STOP_FROM != 0 || STOP_TO != 0)
        {
         int p = Period();
         if(p < 5)
            p = 5;
         else
            if(p > 60)
               p = 60;

         // ---------------------------
         // Web API 呼び出し  ECのみ取得
         //　　
         // 要注意）この例では accessPerDayForBacktest=True とした。理由は、ECデータの経済指標イベントのデータはactualを除いて更新がほぼ起きないため、
         // バックテスト時、1日に１回(GMT時間)の通信で十分と判断したため。actualを利用したり、ORDER/VIXなどを利用する際は、このパラメータははFalseとすべき。
         // またバックテスト時、 mqh の PROGRAMMED_CACHE_ENABLE=True によりローカルにキャッシュを作成し、それを利用する。
         //
         // 無駄な Web API アクセスを減らすため、トレードチャンスの時のみアクセスする方が良い
         // ---------------------------
         bool ret = FP_WEBAPI_REQUEST(targetDatetime,p,Symbol(),false,true,false,True,returnMessage);
         if(!ret && returnMessage != "")
           {
            Print(returnMessage);
            Comment(returnMessage);
            ExpertRemove();
           }

         // ---------------------------
         // 経済指標前後のトレード停止チェック処理
         // ---------------------------
         wantsCancel = FP_CHECK_EVENT_EXISTS(STOP_FROM,STOP_TO,Symbol(),STOP_IMPORTANCE);
         if(wantsCancel)
            return;

        }


      if(rsi >= RSI_Top)
        {
         res = OrderSend(Symbol(),OP_SELL,Lots,Bid,3,0,0,"",MagicNumber,0,Red);
         return;
        }

      if(rsi <= RSI_Bottom)
        {
         res = OrderSend(Symbol(),OP_BUY,Lots,Ask,3,0,0,"",MagicNumber,0,Blue);
         return;
        }
     }
  }



//---

//+------------------------------------------------------------------+
//| Check for close order conditions                                 |
//+------------------------------------------------------------------+
void CheckForClose()
  {
   if(Volume[0] > 1)
      return;

   double rsi = iRSI(NULL,0,RSI_Period,PRICE_CLOSE,RSI_Shift);

   for(int i = 0; i < OrdersTotal(); i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES) == false)
         break;
      if(OrderMagicNumber() != MagicNumber || OrderSymbol() != Symbol())
         continue;

      //--- check order type
      if(OrderType() == OP_BUY)
        {
         if(rsi >= RSI_Top)
           {
            if(!OrderClose(OrderTicket(),OrderLots(),Bid,3,White))
               Print("OrderClose error ",GetLastError());
           }
         break;
        }
      if(OrderType() == OP_SELL)
        {
         if(rsi <= RSI_Bottom)
           {
            if(!OrderClose(OrderTicket(),OrderLots(),Ask,3,White))
               Print("OrderClose error ",GetLastError());
           }
         break;
        }
     }
//---
  }
//+------------------------------------------------------------------+
//| OnTick function                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(OrdersTotal() == 0)
     {
      CheckForOpen();
     }
   else
     {
      CheckForClose();
     }
//---
  }
//+------------------------------------------------------------------+
