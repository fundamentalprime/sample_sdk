//+------------------------------------------------------------------+
//|                                        FundamentalPrime_Base.mq4 |
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
// OnTickで APIの呼び出しと、経済指標前後のトレード停止チェックを行うだけのサンプルです。
//
//
#property copyright "Fundamental Prime , SIA Inc."
#property description "Sample Base"
#property link      "https://www.funda-prime.com"
#property version   "1.00"
#property strict

#include <FundamentalPrime1140.mqh>


input int STOP_FROM = 240;       // 経済指標N分前から新規ポジションを持たない
input int STOP_TO = 360;         // 経済指標N分後まで新規ポジションを持たない
input int STOP_IMPORTANCE = 1;   //０:すべての重要度 / 1:重要度1以上 / 2:重要度2以上 / 3:重要度3以上

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
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
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   EventKillTimer();
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {

   if(Volume[0] > 1)
      return;

   Print("OnTick");

// Period を対応範囲内へ
   int p = Period();
   if(p < 5)
      p = 5;
   else
      if(p > 60)
         p = 60;


//サーバータイムを計算
   datetime targetDatetime = (datetime)MathFloor((long)Time[0] / (60 * p)) * (60 * p);

// 戻り値受信用変数
   long returnStatus = 0;
   long returnHttpStatus = 0;
   string returnApiMessage = "";
   bool shuldTerminate = false;
   string displayMessage = "";


// ---------------------------
// Web API 呼び出し
//　　
// 要注意）この例では accessPerDayForBacktest=false とした
// バックテスト時、1日に１回(GMT時間)の通信で十分な場合、trueとすることにより、通信料を減らすことができる。
// またバックテスト時、 mqh の PROGRAMMED_CACHE_ENABLE=True によりローカルにキャッシュを作成し、それを利用する。
//
// 無駄な Web API アクセスを減らすため、トレードチャンスの時のみアクセスする方が良い
// ---------------------------
   bool fpReturn = FP_WEBAPI_REQUEST(targetDatetime,p,Symbol(),true,true,true,false,returnStatus,returnHttpStatus,returnApiMessage,shuldTerminate,displayMessage);
   if(!fpReturn)
     {
      Print(displayMessage);

      if(shuldTerminate) {
         Alert(displayMessage);
         ExpertRemove();
      }
     }

// ---------------------------
// 経済指標前後のトレード停止チェック処理
// ---------------------------
   bool ret2 = FP_CHECK_EVENT_EXISTS(STOP_FROM,STOP_TO,Symbol(),STOP_IMPORTANCE);
   if(ret2)
      Print("Economic Event EXISTED while STOP_FROM - STOP-TO.");


// ExpertRemove();

  }
//+------------------------------------------------------------------+
