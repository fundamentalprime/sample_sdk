//+------------------------------------------------------------------+
//|                                             FundamentalPrime.mqh |
//|                                                        Ver.1.140 |
//|                                     Fundamental Prime , SIA Inc. |
//|                                      https://www.funda-prime.com |
//|                      https://github.com/fundamentalprime/mt4_mqh |
//+------------------------------------------------------------------+
//
// 当ソースファイルは MT4のMQL4を利用したプログラミングを使い、Fundamental Prime Web API へ
// アクセスする歳の、参考ソースとして用意いたしました。
// プログラミングの一助となれば幸いです。
// 十分な確認のうえご利用ください。
// 当ソースファルの利用に起因するすべての障害・損害の責任は負いかねますのでご理解の上ご利用ください。
// 不具合がありましたらお知らせいただければと存じます。
//
// 利用方法
//    1.FP_CHECK_ENVIRONMENT  環境チェック
//    2.FP_VIX_INITIALIZE     VIX用配列の初期化
//    3.FP_WEBAPI_REQUEST     Fundamental Prime Web API へのアクセス
//    4.FP_CHECK_EVENT_EXISTS FP_WEBAPI_REQUEST で取得したデータ「ec_datas」のなかで、条件に合う経済指標があるかを返却
//
#property copyright "Fundamental Prime , SIA Inc."
#property link      "https://www.funda-prime.com"
#property version   "1.140"
#property strict

/*
 *
 * 最重要パラメータ
 *
 */

// FP認証用パラメータ
// FPUSERID 開発者モードではご自身のFPUSERIDをセット、配布時空白としユーザーが変更できるようにしておく
// FPEAID　配布用のEAの場合、FPEAIDをセット　ユーザー変更不可とすること
input string FPUSERID = "XXX";
string FPEAID = "";

// サーバー関係
string CURRENT_USERAGENT = "Fundamental Prime MT4:" + IntegerToString(TerminalInfoInteger(TERMINAL_BUILD)) + ":" + FPEAID + "@" + FPUSERID;
string COM_URL = "https://XXX.XXX.XXX/XXX";


/*
 *
 * 各種パラメータ
 *
 */

// サーバーがサマータイム(Daylight Saving Time(DST))に対応している場合有効
input  int GMT_Server_Supports_DST = True;
// サーバーの GMT オフセット　非サマータイム時の値をセット
input  int GMT_ServerGMTOffset  = 2;

// デバッグ情報を表示する 受信したデータを Comment & Print する
bool DEBUG_FLAG = true;
// デバッグ情報を表示する & 受信したデータを Comment & Print する
bool DEBUG_FLAG_DETAIL = false;


/* プログラムキャッシュ関連
　*
 * プログラムで実装されたキャッシュファイル使う。OSレベルのWebアクセスのキャッシュ機構とは別もの。
 * バックテスト時のみ有効
 * accessPerDay
 *      同じGMT日付のデータは取得しなくなる。すでに取得されたキャッシュファイルの更新はされない。
 *      VIX、ECの atucual、ORDER の最新値を扱うプログラムでの利用はお勧めしない
 *
 */
bool PROGRAMMED_CACHE_ENABLE = true;
/*
 * キャッシュファイルの保存場所
 * true　=　FILE_COMMON(\Terminal\Common\Files)を使う。複数のMT4をインストールしている場合も共通利用するフォルダに保存する
 * false　=　データフォルダ(\AppData\Roaming\MetaQuotes\Terminal\XXXXXXX\tester\Files)を使う
 */
bool PROGRAMMED_CACHE_USE_COMMONFOLDER = true;
string PROGRAMMED_CACHE_SUBFOLDER = "fp\\cache\\";

//
//FP_WEBAPI_REQUEST で受信したーデタを格納する変数
//
datetime vix_data_dt_array[];    // vixの日付配列　*初回要初期化
double vix_data_value_array[];   // vixのデータ値配列 *初回要初期化
double order_rate[];             // order基準レート
double order_buy[];              // order buy(long)のボリューム
double order_sell[];             // order sell(short)のボリューム　　すべてのorder_ruy+order_sellを合計すると100になる計算。その時点ごとの合計ボリュームを100として計算される
struct Ec_data_structure
  {
   string            gmt_date;
   string            gmt_time;
   bool              close;
   string            country;
   string            symbol;
   string            eventcode;
   bool              prelim;
   int               importance;
   string            previous;
   string            forecast;
   string            actual;
  };
Ec_data_structure ec_datas[];        // ec データ


// 通信関連パラメータ 原則変更不可
// Web APIのコール時、CURRENT_USERAGENT : USERAGENT の設定をお願いします 統計情報のために利用する場合があります
string COM_CONNECT_TIMEOUT = "2";
string COM_CONTROL_SEND_TIMEOUT = "2";
string COM_CONTROL_RECEIVE_TIMEOUT = "2";
string COM_DATA_SEND_TIMEOUT = "2";
string COM_DATA_RECEIVE_TIMEOUT = "2";
int COM_DATA_RETRY = 2;


// DLL に必要な定義（ここから 変更不可）
#define ERROR_INET_OPEN_SESSION 9001
#define ERROR_INET_CONNECT 9002
#define ERROR_INET_REQUEST 9003

#define INTERNET_OPEN_TYPE_PRECONFIG     0           // use the configuration by default
#define INTERNET_FLAG_KEEP_CONNECTION    0x00400000  // do not terminate the connection
#define INTERNET_FLAG_PRAGMA_NOCACHE     0x00000100  // no cashing of the page
#define INTERNET_FLAG_RELOAD             0x80000000  // receive the page from the server when accessing it
#define INTERNET_FLAG_SECURE             0x00800000  // use PCT/SSL if applicable (HTTP)

#define READURL_BUFFER_SIZE   4096
#define INTERNET_OPTION_CONNECT_TIMEOUT 2
#define INTERNET_OPTION_CONTROL_SEND_TIMEOUT 5
#define INTERNET_OPTION_CONTROL_RECEIVE_TIMEOUT 6
#define INTERNET_OPTION_DATA_SEND_TIMEOUT 7
#define INTERNET_OPTION_DATA_RECEIVE_TIMEOUT 8

#import "wininet.dll"
int InternetAttemptConnect(int x);
int InternetOpenW(string sAgent, int lAccessType,
                  string sProxyName = "", string sProxyBypass = "",
                  int lFlags = 0);
int InternetOpenUrlW(int hInternetSession, string sUrl,
                     string sHeaders = "", int lHeadersLength = 0,
                     int lFlags = 0, int lContext = 0);
int InternetReadFile(int hFile, uchar& sBuffer[], int lNumBytesToRead,
                     int& lNumberOfBytesRead[]);
int InternetCloseHandle(int hInet);
bool InternetSetOptionW(int,int,string,int);
bool HttpSendRequestW(int, string, int, string, int);


bool HttpQueryInfoW(int,int,uchar &lpvBuffer[],int& lpdwBufferLength, int& lpdwIndex);


#define HTTP_QUERY_STATUS_CODE 19

#import
// 当mqh内部ステータス（エラーコード等）
#define FPAPI_STATUS_NORMAL 0
#define FPAPI_STATUS_NORMAL_BACKTEST_SKIPPED 1
#define FPAPI_STATUS_ERROR_PARAMETER 1000
#define FPAPI_STATUS_ERROR_OPEN_SESSION 1001
#define FPAPI_STATUS_ERROR_OPEN_URL 1002
#define FPAPI_STATUS_ERROR_PARSE_ERROR 1003
#define FPAPI_STATUS_ERROR_RESPONSE_NG 1004
#define FPAPI_STATUS_ERROR_RESPONSE_SIZE_MISMATCH 1005

enum ec_datas_columns
  {
   EC_COLUMN_ALL_ROW = 0,
   EC_COLUMN_DATATYPE, // = "EC"固定
   EC_COLUMN_EC_ROW,
   EC_COLUMN_GMT_DATE,
   EC_COLUMN_GMT_TIME,
   EC_COLUMN_CLOSE,
   EC_COLUMN_COUNTRY,
   EC_COLUMN_SYMBOL,
   EC_COLUMN_EVENTCODE,
   EC_COLUMN_PRELIM,
   EC_COLUMN_IMPORTANCE,
   EC_COLUMN_PREVIOUS,
   EC_COLUMN_FORECAST,
   EC_COLUMN_ACTUAL
  };

enum cache_type
  {
   CACHE_READ = 0,
   CACHE_WRITE
  };


// 内部 状況保持変数
string api_last_date_or_datetime; // FP_WEBAPI_REQUEST の accessPerDayForBacktest で利用 IsTesting()時 最後に呼び出した日時を保持（重複データ呼び出ししないように制御)
bool ComReEntryFlag;             //通信処理が重複作動しないようにするフラグ

//+------------------------------------------------------------------+
//| 環境チェック                                                          |
//+------------------------------------------------------------------+
bool FP_CHECK_ENVIRONMENT(string &returnMessage)
  {

   if(StringLen(FPUSERID) == 0)
     {
      returnMessage = "Please set FPUSERID.";
      return(false);
     }

// 他のユーザーに配布する場合は FPEAIDは必須　
   /* このソースは開発者向けとして提供しているため、コメントアウト。ユーザーへ配布する際、FPEAID はハードコーディングするため、この処理を使う必要は無い。
   if(StringLen(FPEAID) == 0)
     {
      returnMessage = "Please set FPEAID.";
      return(false);
     }
   */

   if(!IsDllsAllowed())
     {
      returnMessage = "Please allow DLL setting.";
      return(false);
     }

   if(PROGRAMMED_CACHE_ENABLE)
      if(DEBUG_FLAG)
         Print("Programmed Cache enabled.");

   return true;
  }

//+------------------------------------------------------------------+
//| VIX配列　初期化                                                     |
//+------------------------------------------------------------------+
void FP_VIX_INITIALIZE()
  {

   ArrayResize(vix_data_dt_array,0);
   ArrayResize(vix_data_value_array,0);

  }

//+------------------------------------------------------------------+
//　現在のサーバー時間前後に、近いイベントがあるかチェック、同時に通貨、国、重要度のチェックも行う
//
// イベントの時刻前後 minuteBeforeEvent ～minuteAfterEvent に該当するものがあれば true 、何もなければ false を返す
// minuteBeforeEvent : イベントの前N分  (minuteBeforeEvent、minuteAfterEvent ともに0の場合は日時によるチェックは行わない)
// minuteAfterEvent : イベントの後N分
// symbol : 通貨  ""の場合通貨チェックは行わない
// importance : 0～3。 0の場合、すべての重要度。
//
// 戻り値 true=指定条件に該当するイベントがある  false=指定条件に該当するイベントはない
//+------------------------------------------------------------------+
bool FP_CHECK_EVENT_EXISTS(int minuteBeforeEvent,int minuteAfterEvent,string symbol = "",int importance = 0)
  {

//　時間チェックのための基準時間を取得　ここではGMT(APIから返却される日時)で比較する
   datetime APICurrentGMTTime = DateConvertServer2API(TimeCurrent());
   datetime APIDataGMTTime;

//
// イベント（指標発表）の前後 minuteBeforeEvent ～ minuteAfterEvent は新規の注文を行わないというシナリオ

   string ec_symbol = "";
   string targetSymbol = symbol;

   StringToUpper(targetSymbol);

   for(int j = 0; j < ArraySize(ec_datas); j++)
     {

      ec_symbol = ec_datas[j].symbol;
      StringToUpper(ec_symbol);

      if(symbol != "")
         if(ec_symbol != StringSubstr(targetSymbol,0,3) && ec_symbol != StringSubstr(targetSymbol,3,3))
            continue;

      if(ec_datas[j].gmt_time != "")  //時間が設定されていない場合は,条件チェックを行わない
        {

         string strDt = StringSubstr(ec_datas[j].gmt_date,0,4) + "/" + StringSubstr(ec_datas[j].gmt_date,4,2) + "/" + StringSubstr(ec_datas[j].gmt_date,6,2) + " ";
         strDt += StringSubstr(ec_datas[j].gmt_time,0,2) + ":" + StringSubstr(ec_datas[j].gmt_time,2,2) + ":" + StringSubstr(ec_datas[j].gmt_time,4,2);
         APIDataGMTTime = StringToTime(strDt);
         if(minuteBeforeEvent != 0 || minuteBeforeEvent != 0)
           {
            if(importance <= ec_datas[j].importance)
              {
               //Print(APIDataGMTTime + ">" + APICurrentGMTTime + (60 * minuteAfterEvent) + " && " + (APICurrentGMTTime - (60 * minuteBeforeEvent)  + "<" + APIDataGMTTime));
               if((APIDataGMTTime < APICurrentGMTTime + (60 * minuteAfterEvent))
                  && (APICurrentGMTTime - (60 * minuteBeforeEvent) < APIDataGMTTime))
                 {
                  return true;
                 }
              }
           }
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
// キャッシュ処理
// cache_type : CACHE_READ　  キャッシュ読み込み　後続のパラメータに従いキャッシュを検索
//              CACHE_WRITE  キャッシュ書き込み　後続のパラメータに従いキャッシュへ保存
// URL        : キャッシュ対象 URL
// bufferOfWrite : CACHE_WRITE 時、この変数をキャッシュデータとして保存する
// bufferOfRead  : CACHE_READ 時、キャッシュから読み込んだデータはこの変数で返却する
//
// 戻り値 : True = キャッシュから読み込み成功、 False = キャッシュ無し
//+------------------------------------------------------------------+
bool LocalCache(cache_type ope,string URL,string bufferOfWrite,string &bufferOfRead)
  {
   string stringURL = URL;

   Print(stringURL);

// URLをキャッシュファイル名用に変換
   StringReplace(stringURL,".","");
   StringReplace(stringURL,":","");
   StringReplace(stringURL,"/","");
   StringReplace(stringURL,"=","_");
   StringReplace(stringURL,"&","_");
   StringReplace(stringURL,"?","_");
   stringURL = PROGRAMMED_CACHE_SUBFOLDER + "\\" + stringURL;
   stringURL += ".csv";
   StringToLower(stringURL);

// u と e を消す
   string tmp[];
   StringSplit(stringURL,0x5f,tmp); // _

   string strU = "",strE = "";
   for(int i = 0; i < ArraySize(tmp); i++)
     {
      if(tmp[i] == "u")
         strU = tmp[i + 1];

      if(tmp[i] == "e")
         strE = tmp[i + 1];
     }

   if(strU != "")
      StringReplace(stringURL,strU,"X");
   if(strE != "")
      StringReplace(stringURL,strE,"X");


   int fileCOMMON = 0;
   if(PROGRAMMED_CACHE_USE_COMMONFOLDER)
      fileCOMMON = FILE_COMMON;

   if(ope == CACHE_READ)
     {
      if(FileIsExist(stringURL,fileCOMMON))
        {
         string strData = "";
         int h = FileOpen(stringURL,FILE_READ | FILE_ANSI | FILE_TXT | fileCOMMON);
         while(!FileIsEnding(h))
           {
            strData += FileReadString(h,0) + CharToStr(0x0a);
           }
         FileClose(h);

         bufferOfRead = strData;

         if(DEBUG_FLAG)
            Print("Programmed cache Used." + stringURL);

         return true;
        }
      else
        {
         if(DEBUG_FLAG)
            Print("No Programmed cache." + stringURL);
         return false;
        }
     }
   else
     {
      int h = FileOpen(stringURL, FILE_CSV | FILE_WRITE | fileCOMMON);
      if(h < 1)
        {
         FileClose(h);
         return false;
        }
      FileWriteString(h, bufferOfWrite);
      FileFlush(h);
      FileClose(h);
      if(DEBUG_FLAG)
         Print("Programmed cache Saved." + stringURL);
     }
   return false;
  }



//+------------------------------------------------------------------+
// Fundamental Prime Web API　Call　main function
//
// dt         : Web API　の 't' の値（サーバータイム・当関数内でGMTに変換)
// period     : Web API　の 'p' の値
// symbol     : Web API　の 's' の値
// vix        : Web API　の 'd' の値 ※vix有効の場合true
// ec         : Web API　の 'd' の値 ※ec有効の場合true
// order      : Web API　の 'd' の値 ※order有効の場合true
// accessPerDayForBacktest  :  バックテスト時のみ有効
//                 直前アクセスと同一日（または日時）の場合通信をスキップする
//                 trueの場合、直前呼び出しと 't' が日付が同じ場合　FP_WEB_REQUEST_CORE（通信）をｐeriodに関係なくスキップする（さらなる高速化のため)
//                 falseの場合、、直前呼び出しと 't' が日付＋時間（秒を除く）が同じ場合　FP_WEB_REQUEST_CORE（通信）をスキップする
//
// &returnStatus : （返り値）FPAPI_STATUS_～から始まるステータス
// &returnHttpStatus : （返り値） 200/403 などの HtｔｐStatusCode
// &returnMessage  : （返り値）Web API からのメッセージ(WebAPI戻り値がNG時にセットされる)
// &shuldTerminate : （返り値）この戻り値がTrueの場合Expertsの停止を勧める
// &displayMessage : （返り値）エラーメッセージに対応する画面表示用メッセージ
//
//
// 戻り値 : True = Web API（またはキャッシュより）から正常取得 False=取得失敗
//
// この参考mqhでは通信エラーについての詳細エラーコードは吟味しない
//
//+------------------------------------------------------------------+
bool FP_WEBAPI_REQUEST(datetime dt, int period,string symbol,
                       bool vix,bool ec,bool order,
                       bool accessPerDayForBacktest,
                       long &returnStatus,
                       long &returnHttpStatus,
                       string &returnApiMessage,
                       bool & shuldTerminate,
                       string & displayMessage)
  {
   returnStatus = 0;
   returnHttpStatus = 0;
   returnApiMessage = "";
   shuldTerminate = false;
   displayMessage = "";

   if(StringLen(FPUSERID) == 0)
     {
      if(DEBUG_FLAG)
         Print("FP_WEBAPI_CALL:FPUSERID does not set.");
      
      returnStatus = FPAPI_STATUS_ERROR_PARAMETER;
      returnHttpStatus = 0;
      returnApiMessage = "";
      shuldTerminate = true;
      displayMessage = "FPUSERIDが設定されていません";
      return false;
     }

   if(symbol == NULL)
     {
      if(DEBUG_FLAG)
         Print("FP_WEBAPI_CALL:symbol does not set.");

      returnStatus = FPAPI_STATUS_ERROR_PARAMETER;
      returnHttpStatus = 0;
      returnApiMessage = "";
      shuldTerminate = true;
      displayMessage = "シンボル（通貨ペア）がセットされていません";
      return false;
     }

// パラメータ t　のための日時文字列組み立て YYYYMMDDHHNNSS
   string stringDT = "";
   string stringURL = "";

   if(dt == NULL)
     {
      stringDT = TimeToStr(DateConvertServer2API(Time[0]),TIME_DATE | TIME_SECONDS);
      StringReplace(stringDT,":","");
      StringReplace(stringDT,".","");
      StringReplace(stringDT," ","");
      stringDT = StringSubstr(stringDT,0,12) + "00";
     }
   else
     {
      stringDT = TimeToStr(DateConvertServer2API(dt),TIME_DATE | TIME_SECONDS);
      StringReplace(stringDT,":","");
      StringReplace(stringDT,".","");
      StringReplace(stringDT," ","");
     }

   if(IsTesting())
     {
      if(accessPerDayForBacktest)
        {
         if(StringSubstr(stringDT,0,8) == api_last_date_or_datetime)
           {
            if(DEBUG_FLAG)
               Print("Data already on the same date=" + api_last_date_or_datetime + " Web API Access Skipped.");

            returnStatus = FPAPI_STATUS_NORMAL_BACKTEST_SKIPPED;
            returnHttpStatus = 0;
            returnApiMessage = "";
            shuldTerminate = false;
            displayMessage = "";
            
            return true;   
           }
         else
           {
            api_last_date_or_datetime = StringSubstr(stringDT,0,8);
           }
        }
      else
        {
         if(StringSubstr(stringDT,0,12) == api_last_date_or_datetime)
           {
            if(DEBUG_FLAG)
               Print("Data already on the same datetime=" + api_last_date_or_datetime + " Web API Access Skipped.");
            returnStatus = FPAPI_STATUS_NORMAL_BACKTEST_SKIPPED;
            return false;
           }
         else
           {
            api_last_date_or_datetime = StringSubstr(stringDT,0,12);
           }
        }
     }

//通信処理の再入防止チェック
   if(ComReEntryFlag)
      return false;

//通信処理の再入防止フラグ
   ComReEntryFlag = true;


   long status;

   MqlTick tick;
   SymbolInfoTick(Symbol(),tick);

// URL 組み立て
   stringURL += COM_URL + "?t=";
   stringURL += stringDT + "&f=csv&p=" + IntegerToString(period) + "&v=1.0&u=" + FPUSERID;
   stringURL += "&e=" + FPEAID + "&s=" + StringSubstr(symbol,0,6) + "&d=";
   if(vix)
      stringURL += "+vix";
   if(ec)
      stringURL += "+ec";
   if(order)
      stringURL += "+order";


   if(!IsTesting())
     {
      // バックテストではない場合はキャッシュを使わないようにする
      // FundamentalPrime_WebAPI 内でも通信時にキャッシュを使わない設定を行っているが、念のため、seq=XXX と一意となる値をセットし、キャッシュを回避する
      stringURL += "&seq=" + IntegerToString(TimeMinute(TimeLocal())) + IntegerToString(TimeSeconds(TimeLocal()));
     }

//
// 通信実行
//
// 通信が正常に完了するまで COM_DATA_RETRY 回リトライを行う
// 通信が正常に完了とは、レスポンスの OK/NG に関わらず、通信が正常終了することを示す
//
   string apiReturnString = "";
   string message = "";
   long httpStatus = 0;

//
// キャッシュ処理
//
//
   bool hasCache = false;
   if(IsTesting() && PROGRAMMED_CACHE_ENABLE)
     {
      apiReturnString = "";
      hasCache = LocalCache(CACHE_READ,stringURL,"",apiReturnString);

     }

   if(!hasCache)
     {
      for(int retry = 0; retry <= COM_DATA_RETRY; retry++)
        {
         apiReturnString = "";
         message = "";

         apiReturnString = MainAPIAccess(stringURL,status,httpStatus);

         // NG エラー
         if(status == FPAPI_STATUS_NORMAL && StringFind(apiReturnString,"1,1,NG,") != -1)
           {
            //
            // 通常のエラーメッセージが返ってきた
            // パラメータが違う、有効期限切れなどのメッセージを returnMessage で返却する
            // returnHttpCodeは通常200が入っている
            // バックテスト時は処理停止をお勧め(原因調査しないとアクセス数を消費してしまう可能性があるため)
            // リアル運用時はそのまま運用するか停止するか開発者の判断(しばらくしたら回復する場合もあるため)
            // returnMessageによる判断をおすすめ
            //
            string messageArray[];
            if(StringSplit(apiReturnString,0x2c,messageArray) > 0)
              {

               shuldTerminate = ShouldQuitWhenError(messageArray[3],status,httpStatus,displayMessage);
               

               ComReEntryFlag = false;
               return false;
              }
           }
         if(status != FPAPI_STATUS_NORMAL || StringLen(apiReturnString) == 0)
           {
            //
            // 通信系のエラーが返ってきた
            // サーバーが見つからない、などのエラー。メッセージは空文字 httpStatusで状況を判断する
            // returnHttpCodeは通常200以外が入っている。　
            // バックテスト時は処理停止をお勧め(原因調査しないとアクセス数を消費してしまう可能性があるため)
            // リアル運用時はそのまま運用するか停止するか開発者の判断(しばらくしたら回復する場合もあるため)
            // 403はアクセス超過によるIP制限　月初にクリア
            //
            if(retry >= COM_DATA_RETRY - 1)
              {
               if(DEBUG_FLAG)
                  Print("FP WEBAPI CALL:Comm Error Occured : retry=" + IntegerToString(retry + 1) + " status=" + IntegerToString(status) + " " + message + " httpStatusCode=" + IntegerToString(httpStatus));

               shuldTerminate = ShouldQuitWhenError(apiReturnString,status,httpStatus,displayMessage);

               ComReEntryFlag = false;
               return false;
              }
            else
              {
               continue;
              }
           }

         // サーバーのAPI内部でで予期せぬエラー
         if(StringFind(apiReturnString,"Traceback") >= 0)
           {
            //
            // サーバーサイドのエラー
            // サーバーが見つからない、などのエラー。メッセージは空文字 httpStatusで状況を判断する
            // returnHttpCodeは通常200以外が入っている。　
            // 通常は発生しないが、発生した場合は 　returnMessage を控えてお問い合わせください。
            //
            if(retry >= COM_DATA_RETRY - 1)
              {
               if(DEBUG_FLAG)
                  Print("FP WEBAPI CALL:Comm Error Occured : retry=" + IntegerToString(retry + 1) + " " + apiReturnString + " httpStatusCode=" + IntegerToString(httpStatus));

               shuldTerminate = ShouldQuitWhenError(apiReturnString,status,httpStatus,displayMessage);

               ComReEntryFlag = false;
               return false;
              }
            else
              {
               continue;
              }
           }

         break;
        }
     }
   if(IsTesting() && PROGRAMMED_CACHE_ENABLE && !hasCache)
     {
      //
      // キャッシュ保存処理
      //

      string dummy = "";
      //      bool ret = LocalCache(CACHE_WRITE,stringDT,period,symbol,vix,ec,order,accessPerDay,apiReturnString,dummy);
      bool ret = LocalCache(CACHE_WRITE,stringURL,apiReturnString,dummy);


     }

//
// 届いたデータの切り出しと変数・配列へのセット
// VIX : vix_data_dt,vix_data_value
// EC : ec_datas[] （Ec_data_structure構造体)
// ORDER : order_rate[],order_sell[],order_buy[]
//
   string arrayResult[];
   int ret = StringSplit(apiReturnString,0x0a,arrayResult);

   datetime vix_data_dt = 0;
   double vix_data_value = NULL;

   string arrayTemp[];
   ArrayResize(order_rate,0);
   ArrayResize(order_buy,0);
   ArrayResize(order_sell,0);
   ArrayResize(ec_datas,0);

   int i_order = 0,i_ec = 0;
   for(int i = 1; i < ArraySize(arrayResult); i++)
     {
      int r = StringSplit(arrayResult[i],0x2c,arrayTemp);
      if(r > 0)
        {
         if(StringCompare(arrayTemp[1],"VIX",false) == 0)
           {
            string strDt = StringSubstr(arrayTemp[3],0,4) + "/";
            strDt += StringSubstr(arrayTemp[3],4,2) + "/";
            strDt += StringSubstr(arrayTemp[3],6,2) + " ";
            strDt += StringSubstr(arrayTemp[3],8,2) + ":";
            strDt += StringSubstr(arrayTemp[3],10,2) + ":";
            strDt += StringSubstr(arrayTemp[3],12,2);
            vix_data_dt = StringToTime(strDt);
            vix_data_value = StringToDouble(arrayTemp[5]);
            VixAdd(vix_data_dt,vix_data_value);
           }

         else
            if(StringCompare(arrayTemp[1],"OD",false) == 0)
              {
               ArrayResize(order_rate,ArraySize(order_rate) + 1);
               ArrayResize(order_buy,ArraySize(order_buy) + 1);
               ArrayResize(order_sell,ArraySize(order_sell) + 1);

               order_rate[i_order] = StringToDouble(arrayTemp[5]);
               order_sell[i_order] = StringToDouble(arrayTemp[6]);
               order_buy[i_order] = StringToDouble(arrayTemp[7]);
               i_order = i_order + 1;
              }
            else
               if(StringCompare(arrayTemp[EC_COLUMN_DATATYPE],"EC",false) == 0)
                 {
                  ArrayResize(ec_datas,ArraySize(ec_datas) + 1);
                  ec_datas[i_ec].gmt_date = arrayTemp[EC_COLUMN_GMT_DATE];
                  ec_datas[i_ec].gmt_time = arrayTemp[EC_COLUMN_GMT_TIME];
                  ec_datas[i_ec].close = int(arrayTemp[EC_COLUMN_CLOSE]);
                  ec_datas[i_ec].country = arrayTemp[EC_COLUMN_COUNTRY];
                  ec_datas[i_ec].symbol = arrayTemp[EC_COLUMN_SYMBOL];
                  ec_datas[i_ec].eventcode = arrayTemp[EC_COLUMN_EVENTCODE];
                  ec_datas[i_ec].prelim = int(arrayTemp[EC_COLUMN_PRELIM]);
                  ec_datas[i_ec].importance = int(arrayTemp[EC_COLUMN_IMPORTANCE]);
                  ec_datas[i_ec].previous = arrayTemp[EC_COLUMN_PREVIOUS];
                  ec_datas[i_ec].forecast = arrayTemp[EC_COLUMN_FORECAST];
                  ec_datas[i_ec].actual = arrayTemp[EC_COLUMN_ACTUAL];
                  i_ec = i_ec + 1;
                 }
        }
     }


//
// デバッグ表示
//
   if(DEBUG_FLAG_DETAIL)
     {
      string debug = "";
      debug += stringURL + "\n";

      if(ArraySize(arrayResult) > 0)
        {

         debug += "RESPONSE FIRST  LINE : " + arrayResult[0] + "\n";

         if(vix_data_dt != 0)
           {
            debug += "VIX\n";
            string s = TimeToString(vix_data_dt,TIME_DATE | TIME_SECONDS);
            StringReplace(s,":","");
            StringReplace(s,".","");
            debug += s + " " + StringFormat("%.2f",vix_data_value) + "\n";
           }

         if(ArraySize(ec_datas) > 0)
           {
            debug += "EC\n";
            for(int i = 0 ; i < ArraySize(ec_datas) ; i++)
              {
               debug += ec_datas[i].gmt_date + " ";
               debug += ec_datas[i].gmt_time + " ";
               if(ec_datas[i].close)
                 {
                  debug += "1 ";
                 }
               else
                 {
                  debug += "0 ";
                 }

               debug += ec_datas[i].country + " ";
               debug += ec_datas[i].symbol + " ";
               debug += ec_datas[i].eventcode + " ";
               if(ec_datas[i].prelim)
                 {
                  debug += "1 ";
                 }
               else
                 {
                  debug += "0 ";
                 }
               debug += IntegerToString(ec_datas[i].importance) + " ";
               debug += ec_datas[i].previous + " ";
               debug += ec_datas[i].forecast + "\n";
              }
           }

         if(ArraySize(order_rate) > 0)
           {
            debug += "ORDER\n";
            for(int i = 0 ; i < i_order ; i++)
              {
               debug += DoubleToString(order_rate[i]) + " " + DoubleToString(order_sell[i]) + DoubleToString(order_buy[i]) + "\n";
              }
           }

         //         Comment(debug);
         //  Print(debug);

         if(DEBUG_FLAG_DETAIL)
           {
            string resultArray[];
            StringSplit(debug,'\n',resultArray);
            for(int i = 0; i < ArraySize(resultArray); i++)
              {
               Print(resultArray[i]);
              }
           }

        }
     }
   ComReEntryFlag = false;
   return true;
  }


//+------------------------------------------------------------------+
//| Web API　Call　function 　                                         |
//|                                              　                   |
//|                                              　                   |
//+------------------------------------------------------------------+
string MainAPIAccess(string url, long & status,long & httpStatus)
  {
   status = FPAPI_STATUS_NORMAL;
   httpStatus = 0;
   string nil = "";

   int HttpSession = InternetOpenW(CURRENT_USERAGENT, INTERNET_OPEN_TYPE_PRECONFIG, nil, nil, 0);
   if(HttpSession <= 0)
     {
      // エラー処理を行う
      // 戻り値は""(空)、その他 status,httpStatus(未設定=0) を返す
      status =  FPAPI_STATUS_ERROR_OPEN_SESSION;
      return "";
     }

   bool r;
   r = InternetSetOptionW(HttpSession, INTERNET_OPTION_CONNECT_TIMEOUT,COM_CONNECT_TIMEOUT, sizeof(COM_CONNECT_TIMEOUT));
   r = InternetSetOptionW(HttpSession, INTERNET_OPTION_CONTROL_SEND_TIMEOUT, COM_CONTROL_SEND_TIMEOUT, sizeof(COM_CONTROL_SEND_TIMEOUT));
   r = InternetSetOptionW(HttpSession, INTERNET_OPTION_CONTROL_RECEIVE_TIMEOUT, COM_CONTROL_RECEIVE_TIMEOUT, sizeof(COM_CONTROL_RECEIVE_TIMEOUT));
   r = InternetSetOptionW(HttpSession, INTERNET_OPTION_DATA_SEND_TIMEOUT, COM_DATA_SEND_TIMEOUT, sizeof(COM_DATA_SEND_TIMEOUT));
   r = InternetSetOptionW(HttpSession, INTERNET_OPTION_DATA_RECEIVE_TIMEOUT, COM_DATA_RECEIVE_TIMEOUT, sizeof(COM_DATA_RECEIVE_TIMEOUT));

   int HttpRequest = 0;

// バックテストの場合、データも過去のデータで確定しているため、キャッシュをつかう。これにより2回目のバックテストはキャッシュを使うため高速、アクセス数制限のためにも有効な手段
// ※　MT4を再起動すると、キャッシュはクリアされる模様
   if(IsTesting())
     {
      if(DEBUG_FLAG)
         Print("Request(WithCache):" + url);

      HttpRequest = InternetOpenUrlW(HttpSession, url, NULL, 0, 0, 0); // CACHE あり
     }
   else
     {
      if(DEBUG_FLAG)
         Print("Request(NoCache):" + url);

      HttpRequest = InternetOpenUrlW(HttpSession, url, NULL, 0, (int)INTERNET_FLAG_RELOAD | (int)INTERNET_FLAG_PRAGMA_NOCACHE | (int)INTERNET_FLAG_SECURE, 0); // CACHE なし
     }

// HTTP ステータスコードの取得
   uchar cBuff[6];
   int cBuffLength = 6;
   int cBuffIndex = 0;
   int httpQueryInfoW = HttpQueryInfoW(HttpRequest, HTTP_QUERY_STATUS_CODE, cBuff, cBuffLength, cBuffIndex);
   int httpCode = (int) CharArrayToString(cBuff, 0, cBuffLength, CP_UTF8);
   if(httpCode != 0)
     {
      httpStatus = httpCode;
      if(DEBUG_FLAG)
         Print("http status code : " + IntegerToString(httpCode));
     }

   if(HttpRequest <= 0 || httpStatus != 200)
     {
      // エラー処理を行う
      if(HttpRequest > 0)
         InternetCloseHandle(HttpRequest);
      if(HttpSession > 0)
         InternetCloseHandle(HttpSession);

      // 戻り値は""(空)、その他 status,httpStatus(既設定) を返す
      status = FPAPI_STATUS_ERROR_OPEN_URL;
      return "";
     }


// 受信データを string 型へ

   int read[1];
   uchar Buffer[];
   ArrayResize(Buffer, READURL_BUFFER_SIZE + 1);
   string data = "";
   while(true)
     {
      InternetReadFile(HttpRequest, Buffer, READURL_BUFFER_SIZE, read);
      string strThisRead = CharArrayToString(Buffer, 0, read[0],CP_UTF8);
      if(read[0] > 0)
         data = data + strThisRead;
      else
         break;
     }
   if(HttpRequest > 0)
      InternetCloseHandle(HttpRequest);
   if(HttpSession > 0)
      InternetCloseHandle(HttpSession);

// 戻り値は受信したデータ、その他 status=0,httpStatus(既設定) を返す
   return data;
  }



//+------------------------------------------------------------------+
//|DSTを考慮したGMTを取得                                               |
//+------------------------------------------------------------------+
int GetGMTOffset(datetime DT)
  {
   if(GMT_Server_Supports_DST)
     {
      if(IsSummerTime(DT))
         return GMT_ServerGMTOffset + 1;
     }

   return GMT_ServerGMTOffset;
  }

//+------------------------------------------------------------------+
//|API(GMT=0)の日時をサーバー日時へ変換 GetGMTOffsetを利用                |
//+------------------------------------------------------------------+
datetime DateConvertAPI2Server(datetime targetDatetime)
  {
   return targetDatetime + (60 * 60 * GetGMTOffset(targetDatetime));
  }

//+------------------------------------------------------------------+
//|サーバー日時をAPI(GMT=0)のへ変換 GetGMTOffsetを利用                    |
//+------------------------------------------------------------------+
datetime DateConvertServer2API(datetime targetDatetime)
  {
   return targetDatetime - (60 * 60 * GetGMTOffset(targetDatetime));
  }


//+------------------------------------------------------------------+
//|DST (サマータイム)の判断                                              |
//|※古風なコーディングだがわかりやすく                                       |
//|※これ以降はメンテナンス必要                                       |
//+------------------------------------------------------------------+
bool IsSummerTime(datetime targetDatetime)
  {
//3月第2日曜日午前2時〜11月第1日曜日午前2時
   switch(TimeYear(targetDatetime))
     {
      case 2015:
         if(StringToTime("2015.3.8") <= targetDatetime && targetDatetime <= StringToTime("2015.11.1"))
            return true;
         break;
      case 2016:
         if(StringToTime("2016.3.13") <= targetDatetime && targetDatetime <= StringToTime("2016.11.6"))
            return true;
         break;
      case 2017:
         if(StringToTime("2017.3.12") <= targetDatetime && targetDatetime <= StringToTime("2017.11.5"))
            return true;
         break;
      case 2018:
         if(StringToTime("2018.3.11") <= targetDatetime && targetDatetime <= StringToTime("2018.11.4"))
            return true;
         break;
      case 2019:
         if(StringToTime("2019.3.10") <= targetDatetime && targetDatetime <= StringToTime("2019.11.3"))
            return true;
         break;
      case 2020:
         if(StringToTime("2020.3.8") <= targetDatetime && targetDatetime <= StringToTime("2020.11.1"))
            return true;
         break;
      case 2021:
         if(StringToTime("2021.3.14") <= targetDatetime && targetDatetime <= StringToTime("2021.11.7"))
            return true;
         break;
      case 2022:
         if(StringToTime("2022.3.13") <= targetDatetime && targetDatetime <= StringToTime("2022.11.6"))
            return true;
         break;
      case 2023:
         if(StringToTime("2023.3.12") <= targetDatetime && targetDatetime <= StringToTime("2023.11.5"))
            return true;
         break;
      case 2024:
         if(StringToTime("2024.3.10") <= targetDatetime && targetDatetime <= StringToTime("2024.11.3"))
            return true;
         break;
      case 2025:
         if(StringToTime("2025.3.9") <= targetDatetime && targetDatetime <= StringToTime("2025.11.2"))
            return true;
         break;
      case 2026:
         if(StringToTime("2026.3.8") <= targetDatetime && targetDatetime <= StringToTime("2026.11.1"))
            return true;
         break;
      case 2027:
         if(StringToTime("2027.3.14") <= targetDatetime && targetDatetime <= StringToTime("2027.11.7"))
            return true;
         break;
      case 2028:
         if(StringToTime("2028.3.12") <= targetDatetime && targetDatetime <= StringToTime("2028.11.5"))
            return true;
         break;
      case 2029:
         if(StringToTime("2029.3.11") <= targetDatetime && targetDatetime <= StringToTime("2029.11.4"))
            return true;
         break;
      case 2030:
         if(StringToTime("2030.3.10") <= targetDatetime && targetDatetime <= StringToTime("2030.11.3"))
            return true;
         break;
      case 2031:
         if(StringToTime("2031.3.9") <= targetDatetime && targetDatetime <= StringToTime("2031.11.2"))
            return true;
         break;
      case 2032:
         if(StringToTime("2032.3.14") <= targetDatetime && targetDatetime <= StringToTime("2032.11.7"))
            return true;
         break;
      case 2033:
         if(StringToTime("2033.3.13") <= targetDatetime && targetDatetime <= StringToTime("2033.11.6"))
            return true;
         break;
      case 2034:
         if(StringToTime("2034.3.12") <= targetDatetime && targetDatetime <= StringToTime("2034.11.5"))
            return true;
         break;
      case 2035:
         if(StringToTime("2035.3.11") <= targetDatetime && targetDatetime <= StringToTime("2035.11.4"))
            return true;
         break;
      case 2036:
         if(StringToTime("2036.3.9") <= targetDatetime && targetDatetime <= StringToTime("2036.11.2"))
            return true;
         break;
      case 2037:
         if(StringToTime("2037.3.8") <= targetDatetime && targetDatetime <= StringToTime("2037.11.1"))
            return true;
         break;
      case 2038:
         if(StringToTime("2038.3.14") <= targetDatetime && targetDatetime <= StringToTime("2038.11.7"))
            return true;
         break;
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool VixAdd(datetime targetTime,double vix)
  {
   for(int i = 0; i < ArraySize(vix_data_dt_array); i++)
     {
      if(vix_data_dt_array[i] == targetTime)
        {
         vix_data_value_array[i] = vix; // Update
         return true;
        }
      else
        {
         if(vix_data_dt_array[i] < targetTime)
           {
            //行追加確定
            break;
           }
        }
     }

   ArrayResize(vix_data_dt_array,ArraySize(vix_data_dt_array) + 1);
   ArrayResize(vix_data_value_array,ArraySize(vix_data_value_array) + 1);
   vix_data_dt_array[ArraySize(vix_data_dt_array) - 1] = targetTime;
   vix_data_value_array[ArraySize(vix_data_value_array) - 1] = vix;

//  届いたデータをSORT
   for(int k = 0; k < ArraySize(vix_data_dt_array) - 1; k++)
     {
      for(int i = ArraySize(vix_data_dt_array) - 1; i > k; i--)
        {
         if(vix_data_dt_array[i - 1] < vix_data_dt_array[i])
           {
            datetime tmpDt = vix_data_dt_array[i];
            double tmpValue = vix_data_value_array[i];
            vix_data_dt_array[i] = vix_data_dt_array[i - 1];
            vix_data_value_array[i] = vix_data_value_array[i - 1];
            vix_data_dt_array[i - 1] = tmpDt;
            vix_data_value_array[i - 1] = tmpValue;
           }
        }
     }
   return true;
  }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetPipsByPoint(string Currency)
  {
   double Symbol_Digits = MarketInfo(Currency,MODE_DIGITS);
   double Calculated_Point = 0;
   if(Symbol_Digits == 2 || Symbol_Digits == 3)
     {
      Calculated_Point = 0.01;
     }
   else
      if(Symbol_Digits == 4 || Symbol_Digits == 5)
        {
         Calculated_Point = 0.0001;
        }

   return(Calculated_Point);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ShouldQuitWhenError(string apiMessage,long status,long httpStatus,string & returnMessage)
  {
//
// FP_WEBAPI_REQUEST内で発生したエラーについて、どのように対処をした方がよいかを提案、またメッセージを作成
// 利用シーンに合わせて変更してください
// 基本的な考え方は、IsTesting()中は終了を促し不用意なアクセス数を防ぎます。
// フォワード運用時はネットワークの改善を待てば問題ない場合は引き続き動作を続けます。
//

   if(status == FPAPI_STATUS_NORMAL)
     {
      string msg = apiMessage;
      StringReplace(msg,".",""); //末尾にピリオドがある場合は外して比較
      if(msg == "YOU SUBSCRIPTION PLAN DOES NOT SUPPORT BACKTEST")
        {
         returnMessage = "ご利用のプランはバックテストに対応していません";
         if(IsTesting())
            return true;
         else
            return false;
        }
      if(msg == "SUBSCRIPTION IP ADDRESS EXCEEDED LIMIT")
        {
         returnMessage = "プランののIPアドレス数制限に達しました";
         if(IsTesting())
            return true;
         else
            return true;
        }
      if(msg == "DEVELOPER IP ADDRESS EXCEEDED LIMIT")
        {
         returnMessage = "開発者プランのIPアドレス数制限に達しました";
         if(IsTesting())
            return true;
         else
            return true;
        }

      if(msg == "PARAMETER v IS REQUIRED" ||
         msg == "PARAMETER u IS REQUIRED" ||
         msg == "PARAMETER f IS REQUIRED" ||
         msg == "PARAMETER s IS REQUIRED" ||
         msg == "PARAMETER p IS REQUIRED" ||
         msg == "PARAMETER p IS INVALID" ||
         msg == "PARAMETER t IS REQUIRED" ||
         msg == "PARAMETER f IS REQUIRED" ||
         msg == "PARAMETER f IS INVALID" ||
         msg == "PARAMETER d IS REQUIRED")
        {
         returnMessage = "パラメータが不足、または正しくありません。";
         if(IsTesting())
            return true;
         else
            return true;
        }

      if(apiMessage == "SORRY, WE ARE DOWN FOR MAINTENANCE")
        {
         returnMessage = "現在メンテナンス中です";
         if(IsTesting())
            return true;
         else
            return false;
        }
      if(apiMessage == "PARAMETERS IS NOT FOUND")
        {
         returnMessage = "パラメータがありません";
         if(IsTesting())
            return true;
         else
            return true;
        }
      if(apiMessage == "OUT OF TERM")
        {
         returnMessage = "";
         if(IsTesting())
            return true;
         else
            return false;
        }
      if(apiMessage == "NO USER")
        {
         returnMessage = "ユーザー情報が見つかりません";
         if(IsTesting())
            return true;
         else
            return true;
        }
      if(apiMessage == "NO DEV PLAN OR EXPIRED, OR PARAMETER e DOES NOT SET")
        {
         returnMessage = "開発者プランではないか有効期限切れ、またはパラメーが不足しています。";
         if(IsTesting())
            return true;
         else
            return true;
        }
      if(apiMessage == "NO SUBSCRIPTION OR EXPIRED")
        {
         returnMessage = "有効なサブスクリプションが無いか有効期限切れです";
         if(IsTesting())
            return true;
         else
            return true;
        }
      if(apiMessage == "NO DATA(VIX)")
        {
         returnMessage = "VIXのデータはありません";
         if(IsTesting())
            return false;
         else
            return false;
        }
      if(apiMessage == "OUT OF TERM(VIX)")
        {
         returnMessage = "VIX は配信時間外です";
         if(IsTesting())
            return false;
         else
            return false;
        }
      if(apiMessage == "NO DATA(OD)")
        {
         returnMessage = "ORDER のデータはありません";
         if(IsTesting())
            return false;
         else
            return false;
        }
      if(StringFind(apiMessage,"UNSUPPORTED SYMBOL(") > -1)
        {
         returnMessage = "指定のシンボルはオーダーでサポートしていません";
         if(IsTesting())
            return true;
         else
            return false;
        }
      if(apiMessage == "NO DATA(EC)")
        {
         returnMessage = "経済指標のデータはありません";
         if(IsTesting())
            return false;
         else
            return false;
        }
      if(StringFind(apiMessage,"SYSTEM ERROR") > -1)
        {
         returnMessage = "システムエラーです";
         if(IsTesting())
            return true;
         else
            return false;
        }
      if(StringFind(apiMessage,"EXCEPTION ERROR") > -1)
        {
         returnMessage = "システムエラーです";
         if(IsTesting())
            return true;
         else
            return false;
        }
      if(apiMessage == "NOT A PERMITTED DATA TYPE [vix]" ||
         apiMessage == "NOT A PERMITTED DATA TYPE [ec]" ||
         apiMessage == "NOT A PERMITTED DATA TYPE [order]")
        {
         returnMessage = "このプランでは許可されていないデータを要求しました。";
         if(IsTesting())
            return true;
         else
            return true;
        }
      if(apiMessage == "ACCCESS COUNT EXCEEDED LIMIT")
        {
         returnMessage = "アクセス制限数に達しました";
         if(IsTesting())
            return true;
         else
            return true;
        }

      // その他の場合
      returnMessage = apiMessage;
      if(IsTesting())
         return true;
      else
         return true;

     }



   if(status == FPAPI_STATUS_ERROR_OPEN_SESSION)
     {
      returnMessage = "インターネットを確認してください";
      if(IsTesting())
         return true;
      else
         return false;

     }

   if(status == FPAPI_STATUS_ERROR_OPEN_URL)
     {
      if(httpStatus == 403)
        {
         returnMessage = "アクセス数制限に達しました";
         return true;
        }
      else
        {
         returnMessage = "通信中にエラーが発生しました。(" + IntegerToString(httpStatus) + ")";
         if(IsTesting())
            return true;
         else
            return false;
        }
     }

   if(status != FPAPI_STATUS_NORMAL)
     {

      returnMessage = "未知のエラーが発生しました";
      return true;
     }
   return true;

  }
//+------------------------------------------------------------------+
