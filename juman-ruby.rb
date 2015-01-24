# coding: utf-8
# 改変・再頒布自由です。

# <jumanインターフェースの説明>
#　Jumanのラッパーです。簡単に欲しい情報にアクセスできるようにしました。
# 事前にJumanのパスを通しておいてください。
#
# <使用例>
# text = "学問の発展はこの世の中をより良いものにする。"
# j = Juman.new(text)
# p j.array_of(0) 
# #=> ["学問", "の", "発展", "は", "この", "世の中", "を", "より", "良い", "もの", "に", "する", "。"]
# 
# j = Juman.new(text, nil, ["名詞", "形容詞", "動詞"])
# p j.array_of(0) 
# #=> ["学問", "発展", "世の中", "もの", "良い", "する"]
#
# p j.array_of(19)
# #=> ["抽象物", "抽象物", "抽象物", "", "", ""]
#
# p j.array_of(20)
# #=> ["教育・学習", "", "", "", "", ""]
#
#
# <メソッド一覧>
# new(dtring, id, pos) : 初期化。text(文字列)を解析したインスタンスを作成。
#                        idとposはデフォルトでnilになっている。
#                        id(文章のIDや、タイトルなどを想定)はなんでもよいけど、文字列推奨。
#                        pos（parts of speech:pos）は品詞の配列。例えば以下のようなもの。
#                        ex.) pos = ["名詞", "形容詞", "動詞", "副詞"]
#                        使える品詞はClass内の配列Hinshi参照。
#
#               string : Jumanで解析した文章を返す（文字列）
#                   id : インスタンス作成の際に指定したidを返す
#                  pos : インスタンス作成の際に指定した品詞を返す
#               ma_arr : コマンドライン出力の情報を返す（二重配列）
#          array_of(j) : jで指定した形態素情報を返す（配列）
#
#                         0：表記（そのまま）　⇒　いわゆる分かち書き
#                         1：よみ
#                         2：普通表記(原形)　⇒　単語のカウントなどに便利
#                         3：品詞
#                         4：<Jumanマニュアル参照-よくわからない>
#                         5：品詞細分類(活用型)
#                         6：<Jumanマニュアル参照-よくわからない>
#                         7：<Jumanマニュアル参照-よくわからない>
#                         8：<Jumanマニュアル参照-よくわからない>
#                         9：<Jumanマニュアル参照-よくわからない>
#                        10：<Jumanマニュアル参照-よくわからない>
#                        11:-------------
#                        ||:＜割り当てなし＞
#                        16:-------------
#                        17：代表表記　　【出力形式】":（カテゴリ名）"
#                        18：漢字読み　　【出力形式】":（カテゴリ名）"
#                        19：カテゴリ　　 【出力形式】"カテゴリ:（カテゴリ名）"　⇒　単語の階層関係で上位概念を抽出
#                        20：ドメイン　 　【出力形式】"ドメイン：（ドメイン名）"　⇒　文章のジャンル（主題）推定

# Juman Class ******************************************************
class Juman
  require 'open3'
  
  # Jumanクラスのバージョン情報
  Version = "1.0"

  # Jumanのバージョン
  Juman = "7.0"
  
  # 品詞の配列
  Hinshi = ["名詞","助詞","動詞","接尾辞","助動詞","特殊","指示詞","判定詞","未定義語","形容詞","副詞","接頭辞","接続詞","連体詞","感動詞"]
  # 意味カテゴリ(22種)の配列
  Category = ["人","組織・団体","動物","植物","動物-部位","植物-部位","人工物-食べ物","人工物-衣類","人工物-乗り物","人工物-金銭","人工物-その他","自然物","場所-施設","場所-施設部位","場所-自然","場所-機能","場所-その他","抽象物","形・模様","色","数量","時間"]
  #ドメイン（12種）の配列
  Domain = ["文化・芸術","レクリエーション","スポーツ","健康・医学","家庭・暮らし","料理・食事","交通","教育・学習","科学・技術","ビジネス","メディア","政治"]

  # アクセスメソッド（参照のみ）
  attr_reader :ma_arr, :string, :id, :pos

  # 初期化
  # 品詞（parts of speech:pos）
  def initialize(string, id=nil, pos=nil)
    @id = id # 文章のIDや、タイトルなどを想定
    @string = string
    @pos = pos
    @ma_arr = ma(string)
    if pos == nil
      # 何もしない
    else
      @specific_pos = words_of(pos)
    end
  end

  # 対応する情報の配列を返す メソッドarray_of
  # ★JUMANによる各文字の形態素情報
  #  0：表記（そのまま）　⇒　いわゆる分かち書き
  #  1：よみ
  #  2：普通表記(原形)　⇒　単語のカウントなどに用いる
  #  3：品詞
  #  4：
  #  5：品詞細分類(活用型)
  #  6：
  #  7：
  #  8：
  #  9：
  # 10：
  # 11:-------------
  # ||:＜割り当てなし＞
  # 16:-------------
  # 17：代表表記　　【出力形式】":（カテゴリ名）"
  # 18：漢字読み　　【出力形式】":（カテゴリ名）"
  # 19：カテゴリ　　【出力形式】"カテゴリ:（カテゴリ名）"　⇒　単語の階層関係で上位概念を抽出
  # 20：ドメイン    【出力形式】"ドメイン：（ドメイン名）"　⇒　文章のジャンル（主題）推定
  def array_of(i)
    array_of_i = Array.new
    
    case i
    when 0..10
      @ma_arr.each{|e| array_of_i.push(e[i])}
    # 代表表記が指定された場合
    when 17
      @ma_arr.each{|e| array_of_i.push(get_info(e, "代表表記"))}
    # 漢字読みが指定された場合
    when 18
      @ma_arr.each{|e| array_of_i.push(get_info(e, "漢字読み"))}
    # カテゴリが指定された場合
    when 19
      @ma_arr.each{|e| array_of_i.push(get_info(e, "カテゴリ"))}
    # ドメインが指定された場合
    when 20
      @ma_arr.each{|e| array_of_i.push(get_info(e, "ドメイン"))}
    else
      #何もしない
    end
    return array_of_i
  end

  # 指定した品詞の切り出し
  def words_of(hinshi)
    hinshi_arr = Array.new
    hinshi.each do |h|
      @ma_arr.each{|array_of| hinshi_arr.push(array_of) if h == array_of[3]}
    end
    @ma_arr = hinshi_arr
    return hinshi_arr
  end

  private # これ以降はクラス内部のみで使えるメソッド

  # Jumanを用いて形態素解析
  # morphological analysis(ma)
  # Parameter > 
  # Return    > 
  def ma(string)
    maarr = Array.new
    # JUMANはShift-JISしか入力できないので変換（Windos環境）
    string.encode!("Windows-31J", "UTF-8", :invalid => :replace, :undef => :replace, :replace => '') 
    
    # open3で標準入出力を操作してJumanコマンドを実行
    out, err, status = Open3.capture3("juman -b", :stdin_data => string)
    out.each_line do |line|
      line.chomp!.encode!("UTF-16BE", "Windows-31J", :invalid => :replace, :undef => :replace, :replace => '').encode!("UTF-8")
      maarr.push(line.split(/\s/)) unless line == "EOS"
      #maarr.push(line.encode!("Windows-31J", "UTF-8", :invalid => :replace, :undef => :replace, :replace => '') .split(/\s/))
    end
    return maarr
  end

  # 形態素解析情報が入った配列を渡すと情報を取り出すメソッド
  # (Parameter)　e:@ma_arrのn番目の配列 what:"カテゴリ"とか"漢字読み"とかの文字列
  # (Return   ) info:whatで指定したものの情報（文字列）
  def get_info(e, what)
  	info = ""
  	e.each do |elm|
        info = elm.gsub(/#{what}:/, "").delete("\"") if /#{what}:/ =~ elm
    end
    return info #.encode!("Windows-31J", "UTF-8", :invalid => :replace, :undef => :replace, :replace => '') 
  end
end
# End of Juman Class *********************************************



#使い方の例
#text = "学問の発展はこの世の中をより良いものにする。"
#j = Juman.new(text)

# windowsだとコンソール出力はUTF8だと文字化けしちゃうので適宜変換
#p j.array_of(0).map{|e| e.encode!("Windows-31J", "UTF-8")}

