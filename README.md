# Azure Local 2503 Nested Hyper-V での展開方法

## 0. 本手順が想定している環境の概要図

![image](https://github.com/osamut/AzureLocal-Nested-Deployment/blob/main/Nested-AzureLocal%E7%B0%A1%E6%98%93%E6%A7%8B%E6%88%90%E5%9B%B3.png)

> [!CAUTION]
> ### 現在 ”Azure Stack HCI” から ”Azure Local" へのブランド変更中のため、画面によって表記が変わることがありますが、同じものとして処理を続行してください

> [!NOTE]
>- 各手順のスクリーンショットによる解説はこちらにあります！
>- https://github.com/osamut/AzureLocal-Nested-Deployment/blob/main/AzureLocal_%E5%B1%95%E9%96%8B%E3%81%AE%E6%B5%81%E3%82%8C_Nested%E3%82%92%E4%BE%8B%E3%81%AB.pdf
>- 
>- Azure Local 展開には NTP 接続が必要です。もしインターネット上のタイムサーバーと接続できない場合は、ローカルにタイムサーバーを立ててAzure Local 各ノードとの接続を確認してください
>- NTP接続確認は Azure Local OS の Sconfig 画面の 9 から GUI で実施可能です
>- Azure local 各ノード用の VM には vCPU 16、メモリ 32GB、起動ディスク200GB (可変ディスク)、ストレージ用ディスク 100GBx6 (可変ディスク) を割り当てています
>- パラメーター化はしていませんが、変更は可能なので環境に合わせてスクリプト内の数値を変更してください

## 1. ステップ０： Hyper-V 環境と Azure の準備

#### 1. Hyper-V 用の物理マシンを用意し、Windows Server をインストール
- 評価版はこちら　https://www.microsoft.com/ja-jp/evalcenter/evaluate-windows-server-2025?msockid=37cad9ef540b6a4a36f3ccc055716b9c
#### 2. NATを有効化した仮想スイッチを作成
- https://learn.microsoft.com/ja-jp/virtualization/hyper-v-on-windows/user-guide/setup-nat-networkHyper-V
#### 3. 仮想スイッチにつながった Windows Server 仮想マシンを１台作成し、 Active Directory ドメインコントローラー環境を構築
- https://learn.microsoft.com/ja-jp/virtualization/hyper-v-on-windows/user-guide/enable-nested-virtualization
- AVD for Azure Local を利用する場合は AD と Entra ID を同期
#### 4. AD に対して Azure Local 作成のための事前設定を実施
- https://learn.microsoft.com/ja-jp/azure/azure-local/deploy/deployment-prep-active-directory
#### 5. 本 GitHub サイトから「AzureLocal-NestedVM作成テンプレート.ps1」をダウンロード
- ダウンロードしたファイルをノード数分コピーしてパラメータ設定をしておくと並行作業が可能
#### 6. Hyper-V マシンにて Azure Portal の Azure Local 管理画面から Azure Local OS の ISO イメージをダウンロード (約5GB)
- 後で利用するため、ISOファイルのパスを確認しておく
#### 6. Hyper-V マシンにて PowerShell ISE を管理者モードで起動し、作成テンプレートを開く
- PowreShell ISE をノード数分起動してそれぞれでファイルを開くことで Azure Local ノード作成の並行処理を実現

> [!NOTE]  
>- RBAC 権限設定 https://learn.microsoft.com/ja-jp/azure/azure-local/deploy/deployment-arc-register-server-permissions?tabs=powershell

#### 7. Azure ポータル(https://portal.azure.com) にログオン
#### 8. Azure Local に関連するオブジェクトを登録するリソースグループを新規作成
- リソースグループ配下にAzure Local ノードやクラスター、VM、Key Vault、Witness Storage などの各オブジェクトが作成される
#### 10. サブスクリプションに以下のリソースプロバイダーが登録されていることを確認し、登録されていなければ登録する		
	- Microsoft.HybridCompute
	- Microsoft.GuestConfiguration
	- Microsoft.HybridConnectivity
	- Microsoft.AzureStackHCI
#### 11. サブスクリプションに対し、Azure 側の作業をするアカウントに以下の管理権限を付与
	- Azure Stack HCI Administrator
  	- Reader	
#### 12. リソースグループに対して、Azure 側で作業をするアカウントに以下の管理権限を付与
	- Azure Connected Machine Onboarding
	- Azure Connected Machine Resource Administrator
 	- Key Vault Data Access Administrator
  	- Key Vault Secrets Officer　　　      (日本語ポータル作業時は ”キーコンテナーシークレット責任者” を探す)
   	- Key Vault Contributor
   	- Storage Account Contributor

## 2. ステップ１： 疑似的な Azure local ノード (仮想マシン) の作成　　(作成テンプレートのステップ１を利用)
	
#### 1. 作成テンプレートの以下のパラメータを編集
- 1-1: ステップ1 の分：
	- ノード名
	- 準備段階でNAT設定したHyper-V仮想スイッチ名
	- Azure Local ISOイメージのパス
	- 仮想マシンを配置するフォルダー名
- 1-2: ステップ2 の分
	- 管理用 NIC の IP アドレス＝Azure Local の管理に利用
 	- 管理用 NIC のデフォルトゲートウェイ IP アドレス
  	- 管理用 NIC の DNS サーバー IP アドレス
  	- Azure Local OS のパスワード＝Azure Local インストール後に設定したパスワード
#### 2. 「### ステップ１開始」から「### ステップ１終了」までの行を選択し、[選択項目を実行(F8)]をクリック
- 仮想マシンの作成、設定が自動で行われ、Hyper-Vのコンソールが立ち上がる
#### 3. コンソール内では、仮想マシンが自動起動し、ISOからブートするための画面になるのでEnterなどを押下し、Azure Local OSのインストールを実行
- OS は１つだけ違うサイズのディスク(一番上に表示される)にインストール
#### 4. インストール完了後、administrator のパスワードを12文字以上に複雑なパスワードで入力
- パスワード入力後、画面上で Sconfig が起動するが、(現時点では) 数分以内に自動で再起動が始まるため再起動が完了するまで待つとよい
- もし数分経って再起動しない場合は次のステップに進む 
    
## 3. ステップ２：　Azure Local ノードのネットワーク設定　　(作成テンプレートのステップ２を利用)
 
#### 1. 管理用 NIC の IP アドレス、デフォルトゲートウェイ、DNS サーバー IP アドレス、administrator のパスワードなどのパラメーターを記入
- パスワードを処理時に入力したい場合はスクリプトを調整すること 
#### 2.「### ステップ２開始」から「### ステップ２終了」までの行を選択し、[選択項目を実行(F8)]をクリック
- ネットワーク設定が自動で行われ、仮想マシンが自動で再起動
- 再起動したら次のステップに進む 

## 4. ステップ３： 各ノードを Azure Arc へ登録

#### 1. Hyper-V マネージャーにて、ドメインコントローラー仮想マシンに接続
#### 2. ドメインの Administrator でログオン
#### 3. Configurator application をダウンロードし、起動
- https://aka.ms/ConfiguratorAppForHCI
#### 4. Configurator application にてノード１の Azure Arc 接続作業
- 4-4-1: マシン名： ノード１の IP アドレスを入力
- 4-4-2: サインイン： administrator
- 4-4-3: パスワードの入力： Azure Local OS インストール後に設定したパスワードを入力
- 4-4-4: Azure Arc エージェントのセットアップ：
	- [開始]-[次へ]
	- 鉛筆マークをクリックし、[NIC1]を選択して[次へ]
	- 利用するAzure の[サブスクリプションID][リソースグループ][リージョン][テナントID]を入力し[次へ]
	- [完了] 
	- 画面の表示が切り替わり、6つのステップを表示。しばらくすると 6 番目の ARC 構成で認証が促される
	- デバイスコードをコピーし、https://microsoft.com/devicelogin にアクセスしてコードを貼り付け、
	　 Azure Local 展開の権限を持つ Entra ID ユーザーで認証を完了
- 4-4-5: ARC 構成が成功したのち、Azure Portal にて Azure Local マシンが Azure Arc マシンとして登録されているかを確認
#### 5. Configurator application にてノード１の Azure Arc 接続作業
- 4-4-1～4-4-5 と同じ操作をノード２に対して実施

## 5. ステップ４：　Azure Local クラスター展開

### クラスター構築作業
-  Azure ポータルの [Azure Arc] - [Azure Local] 管理画面にて、[すべてのシステム (プレビュ―)] を選択
	-  プレビューではない画面にしたい場合は、画面内の [以前のエクスペリエンスに切り替える] をクリックすると GA 済みの画面が表示される
#### 1. [+作成] メニューから [Azure Local インスタンス] を選択
#### 2. 基本タブ
- 2-1: 展開に利用する [サブスクリプション] と [リソースグループ] を選択
	- リソースグループが違うと画面一番下に Arc に登録したサーバー一覧が表示されないので注意
- 2-2: [インスタンス名] には作成するクラスターの名前を入力
- 2-3: [リージョン]はサポートしているリージョンを入力　※ Japan East で OK
- 2-4: [＋マシンの追加] をクリックし、Azure Arcに接続した Azure Local マシン2台を追加
	- 「Arc 拡張機能がありません」と表示されているので、[拡張機能のインストール] をクリック　※ 15分ほどかかる
	-  Azure Portal の Azure Arc 管理画面にて、マシンの一覧にある Azure Local ノードを選択
	- [設定]の下の[拡張機能]をクリックし、4つの拡張モジュールの作成が完了するのを待つ (MDE.Windows は除く)
- 2-5: すべてのノードが準備完了になったら[選択したマシンの確認]をクリック
- 2-6: キーコンテナ―名では [新しいキーコンテナーの作成] をクリックし、右に出てくる画面で [作成] をクリック
	- 繰り返し同じ作業をした場合は既存の Key Vault を削除するか、Key Vault name を変更する事で対応
	- Key Vault は削除しても削除済みリストに残るので、削除済みリストからさらに削除する必要がある
- 2-7: 作業が完了したら [次へ: 構成] をクリック
#### 3. 構成タブ
 - [新しい構成] が選択されていることを確認し [次へ: ネットワーク] をクリック
 	- テンプレートが用意できている場合はテンプレートを利用可能
#### 4.  ネットワークタブ
- ※ ここは実際の環境に合わせて設定をする必要がある
- ※ 以下は NIC4 枚の環境にて、管理＆VM 用ネットワークに NIC1 と NIC2 を、ストレージ用に NIC3 と NIC4 を利用する想定
- 4-1: [ストレージのネットワークスイッチ] を選択
- 4-2: [管理とコンピューティングのトラフィックをグループ化する] を選択
- 4-3: インテント名「コンピューティング_管理」に対して [NIC1] を選択
- 4-4: [+ このトラフィック用の別のアダプターを選択してください] をクリックして [NIC2] を追加
- 4-5: [ネットワーク設定のカスタマイズ] をクリックして「RDMA プロトコル」を Disabled に変更
- 4-6: インテント名「ストレージ」に対して [NIC3] を選択
- 4-7: 必須項目となっている VLAN ID はデフォルトを受け入れる
- 4-8: [+ このトラフィック用の別のアダプターを選択してください] をクリックして [NIC4] 追加
- 4-9: VLAN ID はデフォルトを受け入れる
- 4-10: [ネットワーク設定のカスタマイズ] をクリックして「RDMA プロトコル」を Disabled に変更
- 4-11: ノードとインスタンスの IP 割り当てが [手動] になっていることを確認　- DHCP 環境があれば自動でもよい
- 4-11: Azure Local が利用する最低 6 つの IP アドレス範囲を用意し、[開始 IP] ~ [終了 IP] として入力
- 4-12: [サブネットマスク　例 255.255.255.0] を入力
- 4-13: [デフォルトゲートウェイの IP アドレス] を入力
- 4-14: [DNS サーバーの IP アドレス] を入力
- 4-15: [サブネットの検証] をクリック
- 4-16: [次へ: 管理] をクリック
#### 5. 管理タブ
- 5-1: Azure から Azure Local クラスターに指示を出す際に利用するロケーション名として [任意のカスタムの場所の名前] を入力
   	- 良く使うので、プロジェクト名や場所、フロアなどを使って、わかりやすい名前を付けておくこと
	- 思い浮かばない時はクラスター名に-cl とつけておくとわかりやすいかも
- 5-2: Azure ストレージアカウント名では、Cloud witness 用に [新規作成]をクリック、さらに右に出てきた内容を確認
	- [作成] をクリックし、Azure ストレージアカウントを作成
- 5-3: ドメイン [例 contoso.com] を入力
- 5-4: OU  [例 OU=test,DC=contoso,DC=com] を入力　　　※Active Directory の準備の際に設定した OU
- 5-5: デプロイアカウントユーザー名を入力　　※ Active Directory の準備の際に指定した Deployment 用のユーザー名
- 5-6: デプロイアカウントユーザーのパスワードを間違えないように入力　※ Deployment 用ユーザーのパスワード
- 5-7: Azure Local マシンのローカル管理者のユーザー名 [administrator] を入力　　※特別な設定をしていなければ Administrator で OK
- 5-8: Azure Local マシンのローカル管理者パスワードを間違えないように入力　　※ Azure Local OS インストール後に設定したパスワードを入力
- 5-9: [次へ: セキュリティ] をクリック
#### 6. セキュリティタブ
- [推奨セキュリティ設定] が選択されていることを確認し [次へ: 詳細設定] をクリック
	- Nested でもデフォルトのまま展開できることを確認済み
 	- 推奨設定の機能を変更したい場合は [カスタマイズされたセキュリティ設定] をクリックして有効にしたい項目のみを選択
#### 7. 詳細設定タブ
- [ワークロード ボリュームと必要なインフラストラクチャ ボリュームを作成する] が選択されていることを確認し[次へ: タグ] をクリック
	- 既定で、Software Defined Storage プールに Infrastructure ボリュームと、Azure Local 各ノードを Owner とする論理ボリュームを自動作成してくれる
#### 8. Azure 上のオブジェクトを管理しやすくする任意のタグをつけ、[次へ: 検証] をクリック
- 検証タブが開き、リソース作成ステップ 7 項目が自動実行される
#### 9. 検証タブ
- 9-1: リソース作成用検証ステップの全てが成功になることを確認
- 9-2: [検証を開始] をクリック
- 9-3: 更に 12 個のチェックが行われ、検証が完了したら [次へ: 確認および作成] をクリック
#### 10. 確認および作成タブ
- [作成] をクリックすると Azure Local クラスターの展開が開始される
   - 画面がリソースグループのデプロイ管理画面に遷移するのでしばらくそのままに
   - 画面の表示が変わらなければ、デプロイ管理画面で [更新] をクリックすることで最新の状況を確認できる
   - 手元の 2 ノードで 2 時間半程度かかった
   - "Deploy Arc infrastructure components" ステップでエラーが出る場合 (HCIノードへの接続を繰り返し行いタイムアウト)、Failover Cluster Manager 画面の自動作成された Resource Bridge VM のネットワーク設定にて、「Enable MAC address spoofing」を有効にすることでエラー回避可能
   - OS の更新やドメイン参加を含め Azure Local 23H2 クラスター作成作業が自動で行われ、終了すると Azure から管理可能な状態になる
   - 途中エラーが出た場合はログを確認するなどして対処し [デプロイの再開] を実施
