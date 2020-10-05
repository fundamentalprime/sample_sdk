# Fundamental Prime Web API Sample Library (.mqh) file for MT4


当ソースファイルは Fundamental Prime Web API へアクセスする MQL4(MT4)による、参考ソースとして用意いたしました。
プログラミングの助けとなれば幸いです。
十分な確認のうえご利用ください。
当ソースファルの利用に起因するすべての障害・損害の責任は負いかねますのでご理解の上ご利用ください。
不具合がありましたらお知らせいただければと存じます。




利用方法

## FP_CHECK_ENVIRONMEN

環境チェック
FPUSERID、FPEIAD、「DLL Allow」の事前チェック

## FP_VIX_INITIALIZE

VIX用配列の初期化

## FP_WEBAPI_REQUEST 

メインの Web API アクセス処理
この中で、プログラムローカルキャッシュも実装されている

## FP_CHECK_EVENT_EXISTS 

FP_WEBAPI_REQUEST で取得したデータ「ec_datas」のなかで、条件に合う経済指標があるかを返却


# 参考 Experts

FundamentalPrime_SampleExperts_RSI.mq4
当 mqh を利用した参考Expertsを用意しました。RSIでトレードするシンプルなEAに Fundamental Prime Web API を使ったトレード可否判定を入れています。
