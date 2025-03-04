# Azure Local 23H2 Nested Hyper-V での展開方法

## 0. 本手順が想定している環境の概要図

![image](https://github.com/osamut/AzureLocal-Nested-Deployment/blob/main/Nested-AzureLocal%E7%B0%A1%E6%98%93%E6%A7%8B%E6%88%90%E5%9B%B3.png)

> [!CAUTION]
> ### 現在 ”Azure Stack HCI” から ”Azure Local" へのブランド変更中のため、画面によって表記が変わることがありますが、同じものとして処理を続行してください

> [!NOTE]  
>- Azure Local 展開には NTP 接続が必要です。もしインターネット上のタイムサーバーと接続できない場合は、ローカルにタイムサーバーを立ててAzure Local 各ノードとの接続を確認してください
>- NTP接続確認は Sconfig の 9 から GUI で実施可能です
>- Azure local 各ノード用の VM には vCPU 16、メモリ 32GB、起動ディスク200GB (可変ディスク)、ストレージ用ディスク 100GBx6 (可変ディスク) を割り当てています
>- パラメーター化はしていませんが、変更は可能なので環境に合わせてスクリプト内の数値を変更してください

## 1. ステップ０： Hyper-V 環境と Azure の準備

#### 1. Hyper-V 用の物理マシンを用意し、Windows Server をインストール
- 評価版はこちら　https://www.microsoft.com/ja-jp/evalcenter/evaluate-windows-server-2025?msockid=37cad9ef540b6a4a36f3ccc055716b9c
#### 2. NATを有効化した仮想スイッチを作成
- https://learn.microsoft.com/ja-jp/virtualization/hyper-v-on-windows/user-guide/setup-nat-networkHyper-V
#### 3. 仮想スイッチにつながった Windows Server 仮想マシンを１台作成し、 Active Directory ドメインコントローラー環境を構築
- AVD for Azure Local を利用する場合は AD と Entra ID を同期
#### 4. AD に対して Azure Local 作成のための事前設定を実施
- https://learn.microsoft.com/ja-jp/azure/azure-local/deploy/deployment-prep-active-directory
#### 5. 本 GitHub サイトから「AzureLocal-NestedVM作成テンプレート.ps1」をダウンロード
- ダウンロードしたファイルをノード数分コピーしておくと作業効率が上がる
#### 6. Hyper-V マシンにて PowerShell ISE を管理者モードで起動し、作成テンプレートを開く
- PowreShell ISE をノード数分起動してそれぞれでファイルを開くと Azure Local ノード作成の並行処理が可能

> [!NOTE]  
>- RBAC 権限設定 https://learn.microsoft.com/ja-jp/azure/azure-local/deploy/deployment-arc-register-server-permissions?tabs=powershell

#### 7. Azure ポータル(https://portal.azure.com) にログオン
#### 8. Azure ポータルを英語に変更
- 不要なトラブルを回避するため
- (本手順書作成時は日本語ポータルでも可能だが、内部処理変更時に言語対応ができていないとエラーになるので)
#### 9. Azure Local に関連するオブジェクトを登録するリソースグループを新規作成
- リソースグループ配下にAzure Local ノードやクラスター、VM、Key Vault、Witness Storage などの各オブジェクトが作成される
- 2024年5月4日時点で Japan East での作業が可能になっている
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
	
#### 1. ノード名や準備段階でNAT設定したHyper-V仮想スイッチ名、Azure Local ISOイメージのパス、仮想マシンを配置するフォルダー名などをパラメーターを記入
#### 2. 「### ステップ１開始」から「### ステップ１終了」までの行を選択し、[選択項目を実行(F8)]をクリック
- 仮想マシンの作成、設定が自動で行われ、Hyper-Vのコンソールが立ち上がる
#### 3. コンソール内では、仮想マシンが自動起動し、ISOからブートするための画面になるのでEnterなどを押下し、Azure Local OSのインストールを実行
- OS は１つだけ違うサイズのディスク(一番上に表示される)にインストール
#### 4. インストール完了後、administrator のパスワードを入力
- パスワード入力後、画面上で Sconfig が起動するが、(現時点では) 数分以内に自動で再起動が始まるため再起動が完了するまで待つとよい
- もし数分経って再起動しない場合は次のステップに進む 
    
## 3. ステップ２：　Azure Local ノードのネットワーク設定　　(作成テンプレートのステップ２を利用)
 
#### 1. 管理用 NIC の IP アドレス、デフォルトゲートウェイ、DNS サーバー IP アドレス、administrator のパスワードなどのパラメーターを記入
- パスワードを処理時に入力したい場合はスクリプトを調整すること 
#### 2.「### ステップ２開始」から「### ステップ２終了」までの行を選択し、[選択項目を実行(F8)]をクリック
- ネットワーク設定が自動で行われ、仮想マシンが自動で再起動
- 再起動したら次のステップに進む 

## 4. ステップ３： 各ノードを Azure Arc へ登録　　(作成テンプレートのステップ３を利用)

#### 1. Azure サブスクリプションIDなどの各パラメーターをスクリプトに記入　(PowerShell ISEから実行はしない)
#### 2. Hyper-V の仮想マシンコンソールに Administrator のパスワードを入力し、ログオン 　~Sconfig が自動起動
#### 3. Sconfig にて「Enter number to select an option:」に 15 と入力して PowerShell の画面に移動
#### 4.「### ステップ３開始」から「### ステップ３終了」までの行をコピーし、仮想マシンコンソールの PowerShell 画面に張り付け
- 途中 デバイス認証用のコードが表示されるのでコードをコピー
- ブラウザーが利用可能な手元のマシンなどで https://microsoft.com/devicelogin にアクセスし、コードを貼り付け、RBAC 設定を行った ID で認証を実施
- そのまま処理が進み、各ノードが Azure Arc に登録される
#### 5. Azure Portal の Azure Arc 管理画面で登録されたノードをクリック
- [設定]の下の[拡張機能]をクリックし、4つの拡張モジュールの作成が完了するのを待つ　　(しばらくすると5つ目も作成されているが気にしない)
- すべてのノードで拡張機能の作成が完了したら次のステップへ
	
## 5. ステップ４：　Azure Local クラスター展開　※ Nested 関係なし

### クラスター構築作業
-  Azure ポータルの [Azure Arc] - [Azure Stack HCI] 管理画面にて、[All Clusters (PREVIEW)] を選択
	-  PREVIEW ではない画面にしたい場合は、画面内の [Old Experience] をクリックすると GA 済みの画面が表示される
#### 1. [+Create] メニューから [Azure Stack HCI Cluster] を選択
#### 2. Basics タブ
- 2-1: 展開に利用する [サブスクリプション] と [リソースグループ] を選択
	- リソースグループが違うと画面一番下に Arc に登録したサーバー一覧が表示されないので注意
- 2-2: [Cluster name] を入力
- 2-3: Region はサポートしているリージョンを入力　※ Japan East で OK
- 2-4: Key vault name では [Create a new key vault] をクリックし、右に出てくる画面で [Create] をクリック
	- 権限付与のリンクが表示されたらクリック 
	- 繰り返し同じ作業をした場合は既存の Key Vault を削除するか、Key Vault name を変更する事で対応
	- Key Vault は削除しても削除済みリストに残るので、削除済みリストからさらに削除する必要がある
 - 2-5: リソースグループ内の Azuer Stack HCI ノードの一覧が表示されるので、クラスターに参加させるノードにチェックを入れし、[Validate selected servers] をクリック
 	- このタイミングでホストのNIC情報を取得するため不要なNICの削除などはこの前に行っておくこと
 - 2-6: Validate が完了したら [Next: Configuration] をクリック
#### 3. Configuration タブ
 - [New configuration] が選択されていることを確認し [Next: Networking] をクリック
 	- テンプレートが用意できている場合はテンプレートを利用
#### 4.  Networking タブ
- ※ ここは実際の環境に合わせて設定をする必要がある
- ※ 以下は NIC4 枚の環境にて、管理＆VM 用ネットワークに NIC1 と NIC2 を、ストレージ用に NIC3 と NIC4 を利用する想定
- 4-1: [Network switch for storage] をクリック
- 4-2: [Group management and compute traffic] をクリック
- 4-3: インテント名「Compute_Management」に対して [NIC1] を選択
- 4-4: [+ Select another adapter for this traffic] をクリックして [NIC2] を追加
- 4-5: [Customize network settings] をクリックして「RDMA Protocol」を Disabled に変更
- 4-6: インテント名「Storage」に対して　[NIC3] を選択
- 4-7: 必須項目となっている VLAN ID はデフォルトを受け入れる
   	- ノード間の通信で利用するためのもの
- 4-8: [+ Select another adapter for this traffic] をクリックして [NIC4] 追加
- 4-9: VLAN ID はデフォルトを受け入れる
- 4-10: [Customize network settings] をクリックして「RDMA Protocol」を Disabled に変更
- 4-11: Azure Local が利用する最低 7 つの IP アドレス範囲を用意し、[Starting IP] ~ [Ending IP] として入力
- 4-12: [サブネットマスク　例 255.255.255.0] を入力
- 4-13: [デフォルトゲートウェイのIPアドレス] を入力
- 4-14: [DNS Server のIPアドレス] を入力
- 4-15: [Next: Management] をクリック
#### 5. Management タブ
- 5-1: Azure から Azure Local クラスターに指示を出す際に利用するロケーション名として [任意のCustom location name] を入力
   	- 良く使うので、プロジェクト名や場所、フロアなどを使って、わかりやすい名前を付けておくこと
	- 思い浮かばない時はクラスター名に-cl とつけておくとわかりやすいかも
- 5-2: Cloud witness 用に [Create new]を クリック、さらに右に出てきた内容を確認
	- 必要に応じて修正のうえ、[Create] をクリックし、Azure Storage Account を作成
- 5-3: [ドメイン名 例 contoso.com] を入力
- 5-4: [OU名 　例 OU=test,DC=contoso,DC=com ] を入力　　　※Active Directory の準備の際に設定したOU
- 5-5: Deployment 用の [Username] を入力　　※ Active Directory の準備の際に指定した Deployment 用のユーザー名
- 5-6: [Password]  [Confirm password] を間違えないように入力
- 5-7: Local administrator としての [Username] を入力　　※特別な設定をしていなければ Administrator で OK
- 5-8: [Password]  [Confirm password] を間違えないように入力
- 5-9: [Next: Security] をクリック
#### 6. Security タブ
- [Recommended security settings] が選択されていることを確認し [Next: Advanced] をクリック
	- Nested でもデフォルトのまま展開できることを確認済み
 	- 推奨設定の機能を変更したい場合は [Custommized security settings] をクリックして有効にしたい項目のみを選択
#### 7. Advanced タブ
- [Create workoad volumes and required infrastructure volumes] が選択されていることを確認し[Next: Tags] をクリック
	- 既定で、Software Defined Storage プールに Infrastructure ボリュームと、Azure Local 各ノードを Owner とする論理ボリュームを自動作成してくれる
#### 8. Azure 上のオブジェクトを管理しやすくする任意のタグをつけ、[Next: Validation] をクリック
#### 9. Validation タブ
- 9-1: 特に問題が無ければ Resource Creation として6つの処理を行うため全て Succeeded になることを確認
- 9-2: [Start Validation] をクリック
- 9-3: 更に 11 個のチェックが行われ Validation が完了したら [Next: Preview + Create] をクリック
#### 10. [Create] をクリックし、Azure Local Cluster Deployment を開始
   - 画面が Azure Local 管理画面の ”Settings” にある「Deployments」が選択された状態に遷移するので [Refresh] をクリックして状況を確認できる
   - 手元の 2 ノードで 2 時間半程度かかった
   - "Deploy Arc infrastructure components" ステップでエラーが出る場合 (HCIノードへの接続を繰り返し行いタイムアウト)、Failover Cluster Manager画面の自動作成されたResource Bridge VM のネットワーク設定にて、「Enable MAC address spoofing」を有効にし、「Protected network」を無効にすることでエラー回避可能
   - OS の更新やドメイン参加を含め Azure Local 23H2 クラスター作成作業が自動で行われ、終了すると Azure から管理可能な状態になる
   - 途中エラーが出た場合はログを確認するなどして対処し [Rerun deployment] を実施
