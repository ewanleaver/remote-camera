###
	written by Kenta Katsura
###

window.skydrop

class window.Skydrop
	@SKYWAY_APIKEY: "4362638a-9e84-11e3-9939-47b360702393";
	@CHUNK_SIZE: 1024 * 1024 # 1MB / 10
	@WINDOW_SIZE: 10

	# -------------------------------------------------------------
	###
	コンストラクタ
	###
	constructor: () ->
		# プロパティ初期化
		# Timers
		@timer_peer_list = null

		# Facebook
		@fb_token = null
		@fb_uid = null
		@fb_friends = {}

		@fb_peers = {}			# 自分が送信側
		@fb_passive_tmp = {}	# pidとconnの関連情報を持つ

		# PeerJS
		@peer = null
		@peer_id = null

		# File
		@file =
			is_loaded: false
			data: null
			name: null
			type: null
			size: 0

		@my_progress = 0

		# 受信中ファイル(id別)
		@recv_files = {}

		# 初期化作業
		@initializeView()
		@initializeReadFile()
		@initializeFacebook()

	# -------------------------------------------------------------
	# フェイズ
	# -------------------------------------------------------------
	phaseToppage: () ->

	phaseSelectFriends: () ->
		# ユーザアイコンの設定
		$(".fb_user_icon").attr("src", @getUrlFacebookIcon(@fb_uid))

		# ログイン後 画面遷移
		@glide.next()

		# 友達リスト取得
		@facebookGetFriends (data) =>
			for u in data
				@fb_friends[u.id] = u

		# Skywayに接続
		@connectServer(@fb_uid)

		# SkyWayからユーザリストの取得
		@timer_peer_list = setInterval(@checkUserList, 2000)

	# -------------------------------------------------------------
	# WebRTC
	# -------------------------------------------------------------
	###
	Peer初期化
	###
	connectServer: (uid) ->
		if(@peer != null)
			console.log "error: already initialized"
			console.log @peer
			return false

		@peer_id = "#{uid}_#{@getUnixTime()}"
		@peer = new Peer(@peer_id, {key: Skydrop.SKYWAY_APIKEY, debug: 3})

		# Peer ID 生成イベント
		@peer.on "open", =>
			console.log "my_id is #{@peer.id}"

		# エラーイベント
		@peer.on "error", =>
			console.log "error"

		# データ受信イベント
		@peer.on "connection", (conn) =>
			# 一時テーブルに格納（後にHelloメッセージが送られてきたら利用する）
			@fb_passive_tmp[conn.peer] = conn

			# 受信時イベントの設定
			conn.on "open", =>
				conn.on "data", @handleReceived

		return true

	###
	ノードに接続する
	###
	connectPeer: (fid, onOpenCallback = null) ->
		if(@fb_peers[fid].conn != null)
			console.log "already connected to #{fid}"
			return

		# 接続
		console.log "connect to #{fid}"

		@fb_peers[fid].conn = @peer.connect(@fb_peers[fid].pid)
		@fb_peers[fid].conn.on "open", =>
			@fb_peers[fid].conn.on "data", @handleReceived

			# 自ノード情報の送信
			@sendHello(fid)

			# コールバック実行
			if onOpenCallback?
				onOpenCallback(fid)

	###
	送信
	###
	sendMsg: (fid, type, msg) ->
		msg.fid = @fb_uid
		msg.type = type

		@fb_peers[fid].conn.send(Base64.encode(JSON.stringify(msg)))

	###
	ユーザーリストを取得
	###
	checkUserList: () =>
		$.get "https://skyway.io/active/list/" + Skydrop.SKYWAY_APIKEY, (list) =>
			if(@fb_uid == null || @fb_token == null)
				return

			# 切断確認用にフラグを作成しておく
			old_fids = Object.keys(@fb_peers)
			for fid in old_fids
				@fb_peers[fid].is_tmp_exist = false

			# 同じFacebookIDを持つノードの中で最新のものを抽出
			user_ids = {}
			for pid in list
				# FacebookIDとログイン日時を分離
				tmp = pid.split("_")
				fid = tmp[0]
				login_date = tmp[1]

				#自分の場合を除く
				if(fid == @fb_uid)
					continue

				if not user_ids[fid]?
					# 初登場
					user_ids[fid] = pid
				else
					# 最新ノードを残す
					if(pid > user_ids[fid])
						user_ids[fid] = pid

			for fid, pid of user_ids
				# 友達リストに存在するかチェック
				if not @fb_friends[fid]?
					continue

				# 既にリストに追加済みの場合
				if @fb_peers[fid]?
					@fb_peers[fid].is_tmp_exist = true

					# 以前のpeerIDと異なるかチェック
					if @fb_peers[fid].pid != pid
						@fb_peers[fid].pid = pid

						# 旧コネクションを破棄
						if(@fb_peers[fid].conn != null)
							@fb_peers[fid].conn.close()
							@fb_peers[fid].conn = null

					continue

				# 接続候補先リストに追加
				@fb_peers[fid] =
					pid: pid
					name: @fb_friends[fid].name
					is_selected: true
					conn: null
					window_count: 0
					progress_count: 0

				console.log "success"
				console.log @fb_friends[fid]

				# 表示
				@addViewFacebookFriends(fid)

			# 存在しなくなったノードを削除
			for fid in old_fids
				if not @fb_peers[fid].is_tmp_exist
					console.log("deleted. [fid = #{fid}]")
					delete @fb_peers[fid]
					@deleteViewFacebookFriends(fid)

	###
	選択ピアにファイル受信要求を送信し始める
	###
	startSendFileReceiveRequest: () ->
		if not @file.is_loaded?
			console.log "error: file not found."
			return false

		# 実行
		@file.send_peer_num = 0
		@file.send_peer_cnt = 0
		for fid, p of @fb_peers
			if @file.is_private == null || @file.is_private == fid
				if p.is_selected == true
					@file.send_peer_num += 1

					if not p.conn?
						# 接続してない場合、接続後に実行
						@connectPeer fid, (connected_fid) =>
							console.log("now, send fileReceiveRequest to #{connected_fid}");
							@sendFileReceiveRequest(connected_fid)
					else
						# すぐに実行
						@sendFileReceiveRequest(fid)

	###
	特定ピアにファイル受信要求を送信
	###
	sendFileReceiveRequest: (fid) ->
		if not @fb_peers[fid].conn?
			console.log "error: have not connected peer yet"
			return false

		# 送信前メッセージ
		@sendMsg fid, "recv_request",
			file_name	: @file.name
			file_type	: @file.type
			file_size 	: @file.size

		console.log @file.size
		console.log("[send] file receive request");

	###
	特定ピアにファイル受信要求を送信
	###
	sendFileReceiveResponse: (fid, is_recv) ->
		if not @fb_peers[fid].conn?
			console.log "error: have not connected passive peer yet"
			return false

		# 送信前メッセージ
		@sendMsg fid, "recv_response",
			is_recv 	: is_recv

		console.log("[send] file receive response");


	###
	チャンク受信確認
	###
	sendRecvChunk: (fid, chunk_recv_cnt, chunk_num) ->
		@sendMsg fid, "recv_chunk",
			chunk_recv_cnt 	: chunk_recv_cnt
			chunk_num 		: chunk_num

	###
	ファイル受信確認
	###
	sendRecvCompleted: (fid) ->
		@sendMsg fid, "recv_completed", {}

	###
	ハンドシェイクメッセージ
	###
	sendHello: (fid) ->
		if not @fb_peers[fid].conn?
			console.log "error: have not connected peer yet"
			return false

		# 送信前メッセージ
		@sendMsg fid, "hello",
			pid 	: @peer_id

	###
	ファイル送信開始
	###
	startSendFile: (fid) ->
		if(@file.is_loaded == false)
			console.log "error: file not found."
			return false

		# 送信前メッセージ
		@sendMsg fid, "file_starting",
			file_name	: @file.name
			file_type	: @file.type
			file_size 	: @file.data.length
			chunk_num	: @file.chunk_num

		# ウィンドウサイズ初期化
		@fb_peers[fid].window_count = 0

		chunk_no = 0
		timer = null
		send_func = () =>
			if(@peer_id == null)
				clearInterval(timer)
				return

			# ウィンドウサイズチェック
			if @fb_peers[fid].window_count == Skydrop.WINDOW_SIZE
				return

			@fb_peers[fid].window_count += 1

			# オフセット
			offset = chunk_no * Skydrop.CHUNK_SIZE

			# 送信サイズ
			if(Skydrop.CHUNK_SIZE + offset > @file.data.length)
				send_size = @file.data.length - offset
			else
				send_size = Skydrop.CHUNK_SIZE

			# 送信
			console.log "send chunk #{chunk_no+1}/#{@file.chunk_num} (offset: #{offset}, size: #{send_size}, length: #{@file.data.length})"

			@sendMsg fid, "file",
				file_name	: @file.name
				data 		: @file.data.substr(offset, send_size)
				chunk_no	: chunk_no
				offset		: offset
				send_size	: send_size

			chunk_no  += 1

			# タイマ終了処理
			if(chunk_no == @file.chunk_num)
				clearInterval(timer)

		# 送信ループ開始
		timer = setInterval(send_func, 50)

	addFileReceiveCompletedCount: () ->
		@file.send_peer_cnt += 1

		if @file.send_peer_cnt == @file.send_peer_num
			# 全員が受信完了
			@hiddenWindowStatus(@fb_uid)
			@visibleWindowStatus(@fb_uid, "ファイルの送信が完了しました", 5000)


	###
	データ受信時イベント
	###
	handleReceived: (message) =>
		console.log "[handle] handleReceived"
		msg = JSON.parse(Base64.decode(message))

		console.log "[recv] #{msg.type}"
		switch msg.type

			# 相手から接続してきた場合のハンドシェイクメッセージ
			when "hello"
				if not @fb_passive_tmp[msg.pid]
					console.log "[error] @fb_passive_tmp dont have #{msg.pid}"
					return

				# 接続情報を保持
				@fb_peers[msg.fid].conn = @fb_passive_tmp[msg.pid]

				# 一時テーブルから削除
				@fb_passive_tmp[msg.pid] = null

			# 受信リクエスト
			when "recv_request"
				console.log msg
				@visibleWindowRecv(msg.fid, msg.file_name, msg.file_size, false)

			# 受信リクエスト許諾
			when "recv_response"
				if msg.is_recv
					@startSendFile(msg.fid)
				else
					@addFileReceiveCompletedCount()

			# チャンク受信確認の受信
			when "recv_chunk"
				@fb_peers[msg.fid].window_count -= 1
				@drawFriendProgressBar(msg.fid, 100 * msg.chunk_recv_cnt / msg.chunk_num)

			# ファイル受信完了
			when "recv_completed"
				@drawFriendProgressBar(msg.fid, 0)
				@addFileReceiveCompletedCount()

			# ファイル送信開始
			when 'file_starting'
				# ファイル受信中表示
				@visibleWindowStatus(msg.fid, "ファイルを受信中です")

				# 初期化
				@recv_files[msg.fid] =
					name: msg.file_name
					type: msg.file_type
					size: msg.file_size
					data: []
					chunk_num: msg.chunk_num
					chunk_recv_cnt: 0

				for i in [0 .. @recv_files[msg.fid].chunk_num - 1]
					@recv_files[msg.fid].data[i] = ""

			# ファイル実体送信
			when 'file'
				console.log "recv file chunk #{msg.chunk_no+1}/#{@recv_files[msg.fid].chunk_num} (offset: #{msg.offset}, size: #{msg.send_size}, length: #{@recv_files[msg.fid].size})"

				@recv_files[msg.fid].data[msg.chunk_no] = msg.data
				@recv_files[msg.fid].chunk_recv_cnt += 1

				# 受信状態表示
				@drawFriendProgressBar(msg.fid, 100 * @recv_files[msg.fid].chunk_recv_cnt / @recv_files[msg.fid].chunk_num)

				# Ack返信
				@sendRecvChunk(msg.fid, @recv_files[msg.fid].chunk_recv_cnt, @recv_files[msg.fid].chunk_num)

				# 終了判定
				if(@recv_files[msg.fid].chunk_recv_cnt == @recv_files[msg.fid].chunk_num)

					# 結合
					result = ""
					for i in [0 .. @recv_files[msg.fid].chunk_num - 1]
						result += @recv_files[msg.fid].data[i]

					# 受信完了連絡
					@sendRecvCompleted(msg.fid)

	 				# BlobURLの作成
					blob = Util.dataURLToBlob(result);
					url = URL.createObjectURL(blob);

					# ダウンロードリンク設定
					element = $("[fid=#{msg.fid}]").find(".window_recv")
					element.find(".skydrop-btn-save")
						.attr("href", url)
						.attr("download", @recv_files[msg.fid].name)

					@drawFriendProgressBar(msg.fid, 0)
					@hiddenWindowStatus(msg.fid)
					@visibleWindowRecv(msg.fid, @recv_files[msg.fid].name, @recv_files[msg.fid].size, true)

			else
				console.log "error: cant understand recv message type #{msg.type}"


	# -------------------------------------------------------------
	# Drag & Drop
	# -------------------------------------------------------------
	###
	D&Dの初期化
	###
	initializeReadFile: () ->
		@addDropEvent($(".droppable"))

	addDropEvent: (element) ->

		# デフォルトのドラッグ処理の無効化
		element.bind "dragover", (event) =>
			@cancelEvent(event)

		# ドラッグ時のデザイン
		element.bind "dragenter", (event) =>
			element.addClass("dropover")
			@cancelEvent(event)
		element.bind "dragleave", (event) =>
			element.removeClass("dropover")
			@cancelEvent(event)
		element.bind "dragend", (event) =>
			element.removeClass("dropover")
			@cancelEvent(event)

		# ドロップ時のイベント設定
		element.bind "drop", (event) =>
			@handleDroppedFile(event)

	###
	指定フレンドのアイコンにD&Dイベントを追加
	###
	addDropEventToFriend: (element, fid) ->
		element = element
		@addDropEvent(element)

		element.unbind "drop"
		element.bind "drop", (event) =>
			@handleDroppedFile(event, fid)

	###
	ドロップ時イベント
	###
	handleDroppedFile: (event ,fid = null) =>
		$(".dropover").removeClass("dropover")

		# デフォルト処理を無効化
		event.preventDefault();
		event.stopPropagation();

		# 先頭のファイルを取得
		file = event.originalEvent.dataTransfer.files[0]

		@fileRead(file, fid)
		return false

	###
	ファイル読み込み
	###
	fileRead: (file ,fid = null) =>
		reader = new FileReader()
		reader.onerror = (event) =>
			console.log "Drop error"
			console.log event

		reader.onabort = (event) =>
			console.log "abort"

		reader.onprogress = (event) =>
			if(event.lengthComputable)
				percentLeaded = Math.round event.loaded / event.total * 100
				if(percentLeaded < 100)
					@drawFriendProgressBar(@fb_uid, percentLeaded)

		reader.onload = (event) =>
			@drawFriendProgressBar(@fb_uid, 100)
			@file =
				is_loaded	: true
				is_private	: fid
				data 		: event.target.result
				name		: file.name
				type		: file.type
				size 		: file.size
				chunk_num	: Math.ceil(event.target.result.length / Skydrop.CHUNK_SIZE)

			@visibleWindowDropped()

		# 読み込み開始
		reader.readAsDataURL(file)

		return false


	# -------------------------------------------------------------
	# Facebook
	# -------------------------------------------------------------
	initializeFacebook: () ->
		$.ajaxSetup(cache: true)
		$.getScript "//connect.facebook.net/ja_JP/all.js", () =>
			# 初期化
			FB.init
				appId: "274159369413442"

			# ログインコールバック設定
			FB.getLoginStatus(@handleFacebookAuthResponseChange)

			# ボタン有効化
			$("#fblogin_button").removeClass("disabled");

	###
	Facebook Login
	###
	facebookLogin: () ->
		# ログイン
		FB.Event.subscribe("auth.authResponseChange", @handleFacebookAuthResponseChange)
		FB.login(null, scope: "user_friends")

	###
	Facebook logout
	###
	facebookLogout: () ->
		FB.logout () ->
			console.log "logout!"
			$('#fblogin_button').removeClass('disabled');
			$('#fblogout_button').addClass('disabled');

	###
	友達リストの取得
	###
	facebookGetFriends: (callback) ->
		if(@fb_token == null)
			return false
		FB.api "/me/friends", (response) =>
			callback(response.data)

	###
	Facebookログイン状態変更イベント
	###
	handleFacebookAuthResponseChange: (response) =>
		console.log "CAHNGE STATUS"
		console.log response

		if (response.status == "connected")
			# 取得
			@fb_uid = response.authResponse.userID;
			@fb_token = response.authResponse.accessToken;

			$(".airdrop_my_icon").attr("fid", @fb_uid)
			$(".airdrop_my_icon .icon > img").attr("src", @getUrlFacebookIcon(@fb_uid))

			# 友達選択画面へ移動
			@phaseSelectFriends()

	getUrlFacebookIcon: (id) =>
		"https://graph.facebook.com/#{id}/picture?width=100&height=100"

	# -------------------------------------------------------------
	# Utils
	# -------------------------------------------------------------
	getUnixTime: () ->
		parseInt((new Date)/1000);


	cancelEvent: (event) ->
		event.preventDefault()
		event.stopPropagation()
		return false

	# -------------------------------------------------------------
	# View
	# -------------------------------------------------------------
	initializeView: () ->
		@canvas_main = $(".airdrop_background").get(0).getContext('2d')

		@friends_count = 0

		# スライダ
		$(".slider").glide
			arrowRightText: ""
			arrowLeftText: ""
			autoplay: false
			circular: false
			arrows: false
			navigation: false
			keyboard: false
		@glide = $('.slider').glide().data('api_glide');

		# 表示
		$(".slider").css("display": "block")

		# リサイズイベント登録
		$(window).bind("resize", @windowResize)

		# FBログインボタン
		$("#fblogin_button").click () =>
			@facebookLogin()

		# FBログアウトボタン
		$("#logout_button").click () =>
			@facebookLogout()
			@glide.prev()
			clearInterval(@timer_peer_list)
			@peer.destroy()
			@peer_id = null

		# Android用アップロードフォーム
		if window.navigator.userAgent.indexOf('Android') > 0
			$(".for_android").css("display", "")
			$(".for_android").change (event) =>
				if event.target.files[0]?
					@fileRead(event.target.files[0])

		# 第二画面状態
		@resizeCanvas()
		@drawCircle()


	addViewFacebookFriends: (fid) ->
		@friends_count = @friends_count + 1

		# 要素作成
		element = $("#for_clone_airdrop_icon").clone()
		element.attr("id", "airdrop_icon_#{fid}")
		element.attr("fid", fid)
		element.attr("friends_count", @friends_count)

		# 位置決定
		pos = @computeFriendsDisplayPosition(@friends_count)
		element.css("bottom", "#{pos.bottom}px")
		element.css("left", "#{pos.left}px")

		# アイコン設定
		element.find(".icon > img").attr("src", @getUrlFacebookIcon(fid))

		element.find("canvas").click (event) =>
			fid = element.attr("fid")
			imgdiv = element.find(".icon")

			if(@fb_peers[fid].is_selected)
				@fb_peers[fid].is_selected = false
				imgdiv.addClass("unselected")

			else
				@fb_peers[fid].is_selected = true
				imgdiv.removeClass("unselected")

		# D&Dイベントの追加
		@addDropEventToFriend(element, fid)

		# 追加
		element.css("display", "none")
		$(".fb_friends_icon_box").append(element)
		element.fadeIn("slow")

	deleteViewFacebookFriends: (fid) ->
		$("[fid=#{fid}]").fadeOut "slow", () =>
			$("[fid=#{fid}]").remove()

		# friends_countを降りなおす
		@friends_count = 0

		$(".fb_friends_icon_box").children().each (target) =>
			console.log target
			@friends_count = @friends_count + 1
			target.attr("friends_count", @friends_count)

		console.log @friends_count
		@windowResize()

	###
	Canvasをリサイズ
	###
	resizeCanvas: () ->
		size = @getCanvasSize()

		$(".airdrop_background")
			.attr("width", size.width)
			.attr("height", size.height)

	###
	Canvasの大きさを取得
	###
	getCanvasSize: () ->
		size =
			width	: $(".content").width()
			height	: $(".content").height()

	###
	円の半径を計算
	###
	computeCircleRadius: (number) ->
		radius = 0
		for i in [1 .. number]
			radius = 100 * i + radius * 0.5
		return radius

	###
	円を描画
	###
	drawCircle: () ->
		size = @getCanvasSize()

		# クリア
		@canvas_main.clearRect(0, 0, size.width, size.height)

		# 描画
		@canvas_main.lineWidth = 1
		@canvas_main.strokeStyle = 'rgb(200, 200, 200)'

		for i in [1 .. 5]
			radius = @computeCircleRadius(i)

			@canvas_main.beginPath()
			@canvas_main.arc(size.width / 2 , size.height - 90, radius, 0, Math.PI*2, false)
			@canvas_main.stroke()

	###
	n番目の円に存在できる友達の数を計算
	###
	computeFriendsNum: (number) ->
		return number + 2

	###
	指定番目の友人がどこに位置するのか計算
	###
	computeFriendsLocation: (count) ->
		# 最初の円は飛ばす(近すぎ)
		i = 2

		while(1)
			if count <= @computeFriendsNum(i)
				pos =
					circle	: i
					num		: count
				return pos

			count = count - @computeFriendsNum(i)
			i = i + 1

	###
	指定番目の友人の画面位置を取得
	###
	computeFriendsDisplayPosition: (count) ->
		location = @computeFriendsLocation(count)

		# 描画間隔theta
		radius = @computeCircleRadius(location.circle)
		theta = 120 / (@computeFriendsNum(location.circle) - 1)

		# 中心座標
		size = @getCanvasSize()
		center =
			bottom 	: 40
			left 	: size.width / 2

		# 求める位置
		pos =
			bottom	: center.bottom + radius * Math.sin(Math.PI / 180 *  (theta * (location.num - 1) + 30))
			left	: center.left - radius * Math.cos(Math.PI / 180 * (theta * (location.num - 1 ) + 30))

		return pos

	###
	進捗状況を表示
	###
	drawFriendProgressBar: (fid, current) =>
		c = $("[fid=#{fid}]").find(".progressbar").get(0).getContext("2d")

		# クリア
		c.clearRect(0, 0, 600, 500)
		if current == 0
			return

		# 描画
		circ = Math.PI * 2;
		quart = Math.PI / 2;
		c.lineWidth = 10.0;
		c.strokeStyle = '#99CC33';
		c.lineCap = 'square';

		if fid == @fb_uid
			progress = @my_progress
		else
			progress = @fb_peers[fid].progress_count

		for i in [progress .. current]
			c.beginPath();
			c.arc(50, 50, 45, -(quart), ((circ) * current / 100) - quart, false);
			c.stroke();

		if fid == @fb_uid
			@my_progress = current
		else
			@fb_peers[fid].progress_count = current


	###
	友達位置を再設定
	###
	resizeDrawFriends: (target_no) ->
		pos = @computeFriendsDisplayPosition(target_no)
		element = $("[friends_count=#{target_no}]")
		element.css("bottom", "#{pos.bottom}px")
		element.css("left", "#{pos.left}px")

	###
	情報ウィンドウの表示・非表示
	###
	visibleWindowStatus: (fid, string, fadeout_millisec = null) ->
		element = $("[fid=#{fid}]").find(".window_status")
		element.find(".status > p").text(string)
		element.css("display", "block")

		if fadeout_millisec != null
			setTimeout () =>
				element.fadeOut "normal"
			, fadeout_millisec

	hiddenWindowStatus: (fid, string) ->
		element = $("[fid=#{fid}]").find(".window_status")
		element.css("display", "none")

	###
	ファイル送信ウィンドの表示・非表示
	###
	visibleWindowDropped: () ->
		element = $("[fid=#{@fb_uid}]").find(".window_dropped")
		element.find(".file_name").text(@file.name)

		size = String(@file.size).replace( /(\d)(?=(\d\d\d)+(?!\d))/g, '$1,' );
		element.find(".file_size").text("(#{size} byte)")

		# 送信ボタン
		element.find(".btn-success").unbind().click (event) =>
			@startSendFileReceiveRequest()
			@hiddenWindowDropped()
			@drawFriendProgressBar(@fb_uid, 0)
			@visibleWindowStatus(@fb_uid, "ファイル送信中")

		# 中止ボタン
		element.find(".btn-danger").unbind().click (event) =>
			@file = null
			@drawFriendProgressBar(@fb_uid, 0)
			@hiddenWindowDropped()

		# アニメーション表示
		element
			.css('opacity', 0)
			.slideDown('slow')
			.animate(
				{ opacity: 1 },
				{ queue: false, duration: 'slow' }
			);


	hiddenWindowDropped: () ->
		element = $("[fid=#{@fb_uid}]").find(".window_dropped")
		element
			.animate(
				{ opacity: 0}
				{ queue: false, duration: 'fast' }
				() =>
					element.css("display", "none")
			)

	###
	ファイル受信ウィンドウの表示・非表示
	###
	visibleWindowRecv: (fid, file_name, file_size, is_savemode) ->
		element = $("[fid=#{fid}]").find(".window_recv")
		element.find(".file_name").text(file_name)

		size = String(file_size).replace( /(\d)(?=(\d\d\d)+(?!\d))/g, '$1,' );
		element.find(".file_size").text("(#{size} byte)")

		# 受信ボタン
		element.find(".skydrop-btn-recv").unbind().click () =>
			@sendFileReceiveResponse(fid, true)
			@hiddenWindowRecvRequest(fid)

		# 中止ボタン
		element.find(".skydrop-btn-abort").unbind().click () =>
			@sendFileReceiveResponse(fid, false)
			@hiddenWindowRecvRequest(fid)

		# 保存ボタン(<a>)
		element.find(".skydrop-btn-save").unbind().click () =>
			@hiddenWindowRecvRequest(fid)
			return true

		if is_savemode == false
			# 受信 or 中止
			element.find(".skydrop-btn-recv").css("display", "")
			element.find(".skydrop-btn-abort").css("display", "")
			element.find(".skydrop-btn-save").css("display", "none")
		else
			# 保存
			element.find(".skydrop-btn-recv").css("display", "none")
			element.find(".skydrop-btn-abort").css("display", "none")
			element.find(".skydrop-btn-save").css("display", "")

		# アニメーション表示
		element
			.css('opacity', 0)
			.slideDown('slow')
			.animate(
				{ opacity: 1 },
				{ queue: false, duration: 'slow' }
			);

	hiddenWindowRecvRequest: (fid) ->
		element = $("[fid=#{fid}]").find(".window_recv")
		element
			.animate(
				{ opacity: 0}
				{ queue: false, duration: 'fast' }
				() =>
					element.css("display", "none")
			)


	###
	リサイズイベント
	###
	windowResize: () =>
		@resizeCanvas()
		@drawCircle()

		if @friends_count > 0
			for i in [1 .. @friends_count]
				@resizeDrawFriends(i)


$ ->

	# 初期化
	skydrop = new Skydrop
	window.skydrop = skydrop


