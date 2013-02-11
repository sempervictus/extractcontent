# -*- coding: utf-8 -*-

# ExtractContent for Ruby 1.9
# modified by mono

# Author:: Nakatani Shuyo
# Copyright:: (c)2007 Cybozu Labs Inc. All rights reserved.
# License:: BSD

# Extract Content Module for html
# ExtractContent : 本文抽出モジュール
#
# I want to extract text from html body and Omowashiki given text.
# - Separated into blocks html, exclude the block with a low score
# - Clustered contiguous blocks acclaimed, make a comparison between cluster further
# - Determined by whether the score contains a specific keyword placement, text length, affiliate links, footer, etc.
# - To block Google AdSense Section Target body is being described, in particular extraction

require 'cgi'

module ExtractContent
  # Default option parameters.
  @default = {
    :threshold => 100,                                                # Thought of as a body score threshold of
    :min_length => 80,                                                # Minimum value of the evaluation block length
    :decay_factor => 0.73,                                            # (The higher the score close to the top of the block smaller) attenuation coefficient
    :continuous_factor => 1.62,                                       # (Judged to be difficult to continuously block the larger coefficient) continuous block
    :punctuation_weight => 10,                                        # Score for punctuation
    :punctuations => /([、。，．！？]|\.[^A-Za-z0-9]|,[^0-9]|!|\?)/,     # Punctuation
    :waste_expressions => /Copyright|All Rights Reserved/i,           # Specify keywords that features contained in the footer
    :debug => false,                                                  # If true, block information to the standard output
  }

  # 実体参照変換
  CHARREF = {
    '&nbsp;' => ' ',
    '&lt;'   => '<',
    '&gt;'   => '>',
    '&amp;'  => '&',
    '&laquo;'=> "\xc2\xab",
    '&raquo;'=> "\xc2\xbb",
  }

  # Sets option parameters to default.
  # Parameter opt is given as Hash instance.
  # デフォルトのオプション値を指定する。
  # 引数は @default と同じ形式で与える。
  def self.set_default(opt)
    @default.update(opt) if opt
  end

  # Analyses the given HTML text, extracts body and title.
  def self.analyse(html, opt=nil)
    # frameset or redirect
    return ["", extract_title(html)] if html =~ /<\/frameset>|<meta\s+http-equiv\s*=\s*["']?refresh['"]?[^>]*url/i

    # option parameters
    opt = if opt then @default.merge(opt) else @default end
    b = binding   # local_variable_set があれば……
    threshold=min_length=decay_factor=continuous_factor=punctuation_weight=punctuations=waste_expressions=debug=nil
    opt.each do |key, value|
      eval("#{key.id2name} = opt[:#{key.id2name}]", b)
    end

    # header & title
    title = if html =~ /<\/head\s*>/im
      html = $' #'
      extract_title($`)
    else
      extract_title(html)
    end

    # Google AdSense Section Target
    html.gsub!(/<!--\s*google_ad_section_start\(weight=ignore\)\s*-->.*?<!--\s*google_ad_section_end.*?-->/m, '')
    if html =~ /<!--\s*google_ad_section_start[^>]*-->/
      html = html.scan(/<!--\s*google_ad_section_start[^>]*-->.*?<!--\s*google_ad_section_end.*?-->/m).join("\n")
    end

    # eliminate useless text
    html = eliminate_useless_tags(html)

    # h? block including title
    html.gsub!(/(<h\d\s*>\s*(.*?)\s*<\/h\d\s*>)/i) do |m|
      if $2.length >= 3 && title.include?($2) then "<div>#{$2}</div>" else $1 end
    end

    # extract text blocks
    factor = continuous = 1.0
    body = ''
    score = 0
    bodylist = []
    list = html.split(/<\/?(?:div|center|td)[^>]*>|<p\s*[^>]*class\s*=\s*["']?(?:posted|plugin-\w+)['"]?[^>]*>/)
    list.each do |block|
      next unless block
      block.strip!
      next if has_only_tags(block)
      continuous /= continuous_factor if body.length > 0

      # Judgment and exclusion list link link
      notlinked = eliminate_link(block)
      next if notlinked.length < min_length

      # Score calculation
      c = (notlinked.length + notlinked.scan(punctuations).length * punctuation_weight) * factor
      factor *= decay_factor
      not_body_rate = block.scan(waste_expressions).length + block.scan(/amazon[a-z0-9\.\/\-\?&]+-22/i).length / 2.0
      c *= (0.72 ** not_body_rate) if not_body_rate>0
      c1 = c * continuous
      puts "----- #{c}*#{continuous}=#{c1} #{notlinked.length} \n#{strip_tags(block)[0,100]}\n" if debug

      # Add and score block extraction
      if c1 > threshold
        body += block + "\n"
        score += c1
        continuous = continuous_factor
      elsif c > threshold # continuous block end
        bodylist << [body, score]
        body = block + "\n"
        score = c
        continuous = continuous_factor
      end
    end
    bodylist << [body, score]
    body = bodylist.inject{|a,b| if a[1]>=b[1] then a else b end }
    [strip_tags(body[0]), title]
  end

  # Extracts title.
  def self.extract_title(st)
    if st =~ /<title[^>]*>\s*(.*?)\s*<\/title\s*>/i
      strip_tags($1)
    else
      ""
    end
  end

  private

  # Eliminates useless tags
  def self.eliminate_useless_tags(html)
    # eliminate useless symbols
    html.gsub!(/[\342\200\230-\342\200\235]|[\342\206\220-\342\206\223]|[\342\226\240-\342\226\275]|[\342\227\206-\342\227\257]|\342\230\205|\342\230\206/,'')

    # eliminate useless html tags
    html.gsub!(/<(script|style|select|noscript)[^>]*>.*?<\/\1\s*>/im, '')
    html.gsub!(/<!--.*?-->/m, '')
    html.gsub!(/<![A-Za-z].*?>/, '')
    html.gsub!(/<div\s[^>]*class\s*=\s*['"]?alpslab-slide["']?[^>]*>.*?<\/div\s*>/m, '')
    html.gsub!(/<div\s[^>]*(id|class)\s*=\s*['"]?\S*more\S*["']?[^>]*>/i, '')

    html
  end

  # Checks if the given block has only tags without text.
  def self.has_only_tags(st)
    st.gsub(/<[^>]*>/im, '').gsub("&nbsp;",'').strip.length == 0
  end

  # Judgment and exclusion list link link
  def self.eliminate_link(html)
    count = 0
    notlinked = html.gsub(/<a\s[^>]*>.*?<\/a\s*>/im){count+=1;''}.gsub(/<form\s[^>]*>.*?<\/form\s*>/im, '')
    notlinked = strip_tags(notlinked)
    return "" if notlinked.length < 20 * count || islinklist(html)
    return notlinked
  end

  # Decision linked list
  # To be excluded as non-text list if
  def self.islinklist(st)
    if st=~/<(?:ul|dl|ol)(.+?)<\/(?:ul|dl|ol)>/im
      listpart = $1
      outside = st.gsub(/<(?:ul|dl)(.+?)<\/(?:ul|dl)>/im, '').gsub(/<.+?>/m, '').gsub(/\s+/, ' ')
      list = listpart.split(/<li[^>]*>/)
      list.shift
      rate = evaluate_list(list)
      outside.length <= st.length / (45 / rate)
    end
  end

  # Evaluate the likelihood of a linked list
  def self.evaluate_list(list)
    return 1 if list.length == 0
    hit = 0
    list.each do |line|
      hit +=1 if line =~ /<a\s+href=(['"]?)([^"'\s]+)\1/im
    end
    return 9 * (1.0 * hit / list.length) ** 2 + 1
  end

  # Strips tags from html.
  def self.strip_tags(html)
    st = html.gsub(/<.+?>/m, '')
    # Convert from wide character to ascii
    st.gsub!(/([\357\274\201-\357\274\272])/){($1.bytes.to_a[2]-96).chr} # symbols, 0-9, A-Z
    st.gsub!(/([\357\275\201-\357\275\232])/){($1.bytes.to_a[2]-32).chr} # a-z
    st.gsub!(/[\342\224\200-\342\224\277]|[\342\225\200-\342\225\277]/, '') # keisen
    st.gsub!(/\343\200\200/, ' ')
    self::CHARREF.each{|ref, c| st.gsub!(ref, c) }
    st = CGI.unescapeHTML(st)
    st.gsub(/[ \t]+/, " ")
    st.gsub(/\n\s*/, "\n")
  end

end

