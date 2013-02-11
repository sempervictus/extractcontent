# - * - Coding: utf-8 - * -

# ExtractContent for Ruby 1.9
# Modified by mono

# Author :: Nakatani Shuyo
# Copyright :: (c) 2007 Cybozu Labs Inc. All rights reserved.
# License :: BSD

# Extract Content Module for html
# ExtractContent: Text extraction module
#
# I want to extract text from html body and Omowashiki given text.
# - Separated into blocks html, exclude the block with a low score
# - Clustered contiguous blocks acclaimed, make a comparison between cluster further
# - Determined by whether the score contains a specific keyword placement, text length, affiliate links, footer, etc.
# - To block Google AdSense Section Target body is being described, in particular extraction

require 'cgi'

module ExtractContent
  # Default option parameters.
  @ Default = {
    : The threshold for the score to be considered threshold => 100, the body #
    : The minimum value of the block length to do min_length => 80, # evaluation
    : Decay_factor => 0.73, (the higher the score close to the top of the block smaller) attenuation coefficient #
    : Continuous_factor => 1.62, (judged to be difficult to continuously block the larger coefficient) contiguous blocks #
    : Punctuation_weight => 10, score for punctuation #
    : Punctuations => / ([..!?,,] |.!? \ [^ A-Za-z0-9] |, [^ 0-9] | | \) /, punctuation #
    : Waste_expressions => / Copyright | Specifies a keyword that contains the characteristic All Rights Reserved / i, the # footer
    : If debug => false, of # true, block information to the standard output
  }

  # Convert entity references
  CHARREF = {
    '' => ',
    '<' => '<',
    '>' => '>',
    '&' => '&',
    '«' =>" \ Xc2 \ xab ",
    '»' =>" \ Xc2 \ xbb ",
  }

  # Sets option parameters to default.
  # Parameter opt is given as Hash instance.
  # Specify the default option values.
  # Argument to be in the same format as the @ default.
  def self.set_default (opt)
    @ Default.update (opt) if opt
  end

  # Analyses the given HTML text, extracts body and title.
  def self.analyse (html, opt = nil)
    # Frameset or redirect
    return ["", extract_title (html)] if html = ~ / <\ / frameset> | <meta\s+http-equiv\s*=\s*["']?refresh['"]?[^> ] * url / i

    # Option parameters
    opt = if opt then@default.merge (opt) else @ default end
    If there is a b = binding # local_variable_set ......
    threshold = min_length = decay_factor = continuous_factor = punctuation_weight = punctuations = waste_expressions = debug = nil
    opt.each do | key, value |
      eval ("# {key.id2name} = opt [: # {key.id2name}]", b)
    end

    # Header & title
    title = if html = ~ / <\ / head \ s *> / im
      html = $ '#'
      extract_title ($ `)
    else
      extract_title (html)
    end

    # Google AdSense Section Target
    ! html.gsub (/ <-! \ s * google_ad_section_start \ (weight = ignore \) \ s * ->. *? <-!. \ s * google_ad_section_end * -?> / m,'')
    if html = ~ / <-! \ s * google_ad_section_start [^>] * -> /
      html = html.scan (/ <-! \ s * google_ad_section_start [^>] * -> * <-.?!. \ s * google_ad_section_end * -?> / m). join ("\ n" )
    end

    # Eliminate useless text
    html = eliminate_useless_tags (html)

    # H? Block including title
    html.gsub (/ (<h\d\s*> \ s * (*) \ s * <\ / h \ d \ s *>) / i.?) do |! m |
      if $ 2.length> = 3 && title.include? ($ 2) then "<div> # {$ 2} </ div>" else $ 1 end
    end

    # Extract text blocks
    factor = continuous = 1.0
    body =''
    score = 0
    bodylist = []
    list = html.split (/ <\ / (:?? div | center | td) [^>] *> | <p\s*[^>] * class \ s * = \ s * ["']? (:? posted | plugin-\ w +) ['"] [^>] *> /)?
    list.each do | block |
      next unless block
      block.strip!
      next if has_only_tags (block)
      continuous / = continuous_factor if body.length> 0

      # Judgment and exclusion list link link
      notlinked = eliminate_link (block)
      next if notlinked.length <min_length

      # Score calculation
      c = (notlinked.length + notlinked.scan (punctuations). length * punctuation_weight) * factor
      factor * = decay_factor
      . not_body_rate = block.scan (waste_expressions) length + block.scan. (/ amazon [a-z0-9 \ \ / \ -.? \ &] + -22 / i) length / 2.0
      c * = (0.72 ** not_body_rate) if not_body_rate> 0
      c1 = c * continuous
      puts "----- # {c} * # {continuous} = # {c1} # {notlinked.length} \ n # {strip_tags (block) [0,100]} \ n" if debug

      # Add and score block extraction
      if c1> threshold
        body + = block + "\ n"
        score + = c1
        continuous = continuous_factor
      elsif c> threshold # continuous block end
        bodylist << [body, score]
        body = block + "\ n"
        score = c
        continuous = continuous_factor
      end
    end
    bodylist << [body, score]
    body = bodylist.inject {| a, b | if a [1]> = b [1] then a else b end}
    [Strip_tags (body [0]), title]
  end

  # Extracts title.
  def self.extract_title (st)
    if st = ~ / <title[^>] *> \ s * (. *?) \ s * <\ / title \ s *> / i
      strip_tags ($ 1)
    else
      ""
    end
  end

  private

  # Eliminates useless tags
  def self.eliminate_useless_tags (html)
    # Eliminate useless symbols
    ! html.gsub (/ [\ 342 \ 200 \ 230 - \ 342 \ 200 \ 235] | [\ 342 \ 206 \ 220 - \ 342 \ 206 \ 223] | [\ 342 \ 226 \ 240 - \ 342 \ 226 \ 275] | [\ 342 \ 227 \ 206 - \ 342 \ 227 \ 257] | \ 342 \ 230 \ 205 | \ 342 \ 230 \ 206 /,'')

    # Eliminate useless html tags
    ! html.gsub (/.? <(script | style | select | noscript) [^>] *> * <\ / \ 1 \ s *> / im,'')
    ! html.gsub (/ <-!. * -?> / m,'')
    html.gsub! (/ <! [A-Za-z]. *?> /,'')
    html.gsub! (/ <div\s[^>] * class \ s * = \ s * ['"]? alpslab-slide ["']? [^>] *>. *? <\ / div \ s *> / m,'')
    ! html.gsub (/ <div\s[^>] * (id | class) \ s * = \ s * ['"?] \ S * more \ S * ["'] [^>] *>? / i,'')

    html
  end

  # Checks if the given block has only tags without text.
  def self.has_only_tags (st)
    st.gsub (/ <[^>] *> / im,''). gsub ("",''). strip.length == 0
  end

  # Judgment and exclusion list link link
  def self.eliminate_link (html)
    count = 0
    (.? / <a\s[^>] *> * <\ / a \ s *> / im) notlinked = html.gsub {count + = 1;''}. gsub (/ <form\s[^> ] *>. *? <\ / form \ s *> / im,'')
    notlinked = strip_tags (notlinked)
    return "" if notlinked.length <20 * count | | islinklist (html)
    return notlinked
  end

  # Decision linked list
  # To be excluded as non-text list if
  def self.islinklist (st)
    if st = ~ / <(:? ul | dl | ol) <\ / (+.?) (:? ul | dl | ol)> / im
      listpart = $ 1
      outside = st.gsub (/ <(:? ul | dl) (+) <\ / (:.?? ul | dl)> / im,'')..? gsub (/ <+> / m, ' '). gsub (/ \ s + /,' ')
      list = listpart.split (/ <li[^>] *> /)
      list.shift
      rate = evaluate_list (list)
      outside.length <= st.length / (45 / rate)
    end
  end

  # Evaluate the likelihood of a linked list
  def self.evaluate_list (list)
    return 1 if list.length == 0
    hit = 0
    list.each do | line |
      hit + = 1 if line = ~ / <a \ s + href = (['"]?) ([^"' \ s] +) \ 1/im
    end
    return 9 * (1.0 * hit / list.length) ** 2 + 1
  end

  # Strips tags from html.
  def self.strip_tags (html)
    st = html.gsub (/ <. +?> / m,'')
    # Convert from wide character to ascii
    st.gsub! (/ ([\ 357 \ 274 \ 201 - \ 357 \ 274 \ 272]) /) {. ($ 1.bytes.to_a [2] -96) chr} # symbols, 0-9, AZ
    st.gsub! (/ ([\ 357 \ 275 \ 201 - \ 357 \ 275 \ 232]) /) {. ($ 1.bytes.to_a [2] -32) chr} # az
    ! st.gsub (/ [\ 342 \ 224 \ 200 - \ 342 \ 224 \ 277] | [\ 342 \ 225 \ 200 - \ 342 \ 225 \ 277] /,'') # keisen
    st.gsub! (/ \ 343 \ 200 \ 200 /, '')
    self :: CHARREF.each {| ref, c |! st.gsub (ref, c)}
    st = CGI.unescapeHTML (st)
    st.gsub (/ [\ t] + /, "")
    st.gsub (/ \ n \ s * /, "\ n")
  end

end
