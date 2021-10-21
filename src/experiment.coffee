# coffeelint: disable=max_line_length, indentation

getSearchParam = (key) ->
  sp = new URLSearchParams(location.search)
  sp.get(key)

searchParams = new URLSearchParams(location.search)
SHOW = searchParams.get('show')
PROLIFIC = searchParams.get('hitId') == 'prolific'
DEBUG = SHOW == 'debug' or mode == "debug"

DEMO = mode is "demo"
LOCAL = mode is "{{ mode }}"

CONDITION = parseInt condition
if isNaN CONDITION
  CONDITION = 6

EXPERIMENT = parseInt(searchParams.get('exp'))
# if isNaN EXPERIMENT
#   EXPERIMENT = parseInt(prompt('Which experiment?'))
#   console.log EXPERIMENT

PASSED_INSTRUCT = false
BLOCKS = undefined
PARAMS = undefined
TRIALS = undefined
WATCH_TRIALS = undefined
STRUCTURE = undefined
N_TRIAL = undefined
SELECTED_WATCH = undefined
SKIP_BUTTON = DEBUG
WATCH_START = parseInt(searchParams.get('trial') or "1") - 1

SCORE = 0
BEST_VAL = undefined
BEST_VAL_WORD = undefined

calculateBonus = undefined
getTrials = undefined

if DEMO
  SKIP_BUTTON = false

N_TRAIN = 3
N_TRAIN_REWARD = 10
N_TEST = 25

psiturk = new PsiTurk uniqueId, adServerLoc, mode
saveData = ->
  new Promise (resolve, reject) ->
    if DEMO or DEBUG
      resolve()
      return
    timeout = delay 10000, ->
      reject('timeout')

    psiturk.saveData
      error: ->
        clearTimeout timeout
        console.log 'Error saving data!'
        reject('error')
      success: ->
        clearTimeout timeout
        console.log 'Data saved to psiturk server.'
        resolve()


$(window).resize -> checkWindowSize 800, 680, $('#jspsych-target')
$(window).resize()
$(window).on 'load', ->
  $(window).on 'popstate', ->
    location.reload true
  if DEMO
    runDemo()
  else
    loadExperiment()

makeParams = () ->
  cb = new ConditionBuilder(CONDITION)
  params =
    inspectCost: 0
    bonusRate: .005
    clickDelay: 3000
    # clickDelay: cb.choose [1000,2000,3000]

  _.extend params, switch EXPERIMENT
    when 1
      variance: 'constant'
      branching: '412'
      expandOnly: true
    when 2
      variance: cb.choose ['decreasing', 'constant', 'increasing']
      branching: '41111'
      expandOnly: true
    when 3
      variance: cb.choose ['decreasing', 'constant', 'increasing']
      branching: '412'
      expandOnly: false

  fromSearch = mapObject(Object.fromEntries(searchParams), maybeJson)
  updateExisting(params, fromSearch)
  if params.variance is 'constant'
    BEST_VAL = "$10"
    BEST_VAL_WORD = "ten"
  else
    if EXPERIMENT is 2
      BEST_VAL = "$20"
      BEST_VAL_WORD = "twenty"
    else if EXPERIMENT is 3
      BEST_VAL = "$18"
      BEST_VAL_WORD = "18"
  params

loadExperiment = () ->
  $('#load-icon').show()
  # Load data and test connection to server.
  slowLoad = -> $('slow-load')?.show()
  loadTimeout = delay 12000, slowLoad

  psiturk.preloadImages [
    'static/images/spider.png'
  ]

  delay (if DEBUG or LOCAL or DEMO then 100 else 3000), ->

    PARAMS = makeParams()
    psiturk.recordUnstructuredData 'params', PARAMS
    # psiturk.recordUnstructuredData 'startTime', String(new Date())

    STRUCTURE = loadJson "static/json/structure/#{PARAMS.branching}.json"
    TRIALS = loadJson "static/json/rewards/exp#{EXPERIMENT}_#{PARAMS.variance}.json"
    console.log "loaded #{TRIALS?.length} trials"

    getTrials = do ->
      t = _.shuffle TRIALS
      idx = 0
      return (n) ->
        idx += n
        t.slice(idx-n, idx)

    if DEMO
      return initializeExperiment()
    if LOCAL
      createStartButton()
      clearTimeout loadTimeout
    else
      saveData().then ->
        $('#load-icon').hide()
        $('#slow-load').hide()
        clearTimeout loadTimeout
        createStartButton()
      .catch ->
        clearTimeout loadTimeout
        $('#data-error').show()
      
      # $.get 'https://www.cloudflare.com/cdn-cgi/trace', (data) ->
      #   psiturk.recordUnstructuredData 'trace', data
      #   if LOCAL
      #     clearTimeout loadTimeout
      #     delay 500, createStartButton
      #   else
      #     saveData().then(->
      #       clearTimeout loadTimeout
      #       delay 500, createStartButton
      #     ).catch(->
      #       clearTimeout loadTimeout
      #       $('#data-error').show()
      #     )

createStartButton = ->
  if SKIP_BUTTON
    initializeExperiment()
  else
    $('#success-load').show()
    $('#load-btn').click initializeExperiment

class Block
  constructor: (config) ->
    _.extend(this, config)
    @_block = this  # allows trial to access its containing block for tracking state
    if @_init?
      @_init()

initializeExperiment = () ->
  $('#load-icon').hide()
  $('#slow-load').hide()

  $('#demo-landing').html("")
  psiturk.recordUnstructuredData 'time_start', Date.now()

  $('#jspsych-target').html ''
  console.log 'initialize experiment'

  #  ======================== #
  #  ========= TEXT ========= #
  #  ======================== #

  # These functions will be executed by the jspsych plugin that
  # they are passed to. String interpolation will use the values
  # of global variables defined in this file at the time the function
  # is called.

  # text =
  #   debug: -> if DEBUG then "`DEBUG`" else ''

  # ================================= #
  # ========= BLOCK CLASSES ========= #
  # ================================= #

  class TextBlock extends Block
    type: 'text'
    cont_key: []

  class ButtonBlock extends Block
    type: 'button-response'
    is_html: true
    choices: ['Continue']
    button_html: '<button class="btn btn-primary btn-lg">%choice%</button>'

  class QuizLoop extends Block
    loop_function: (data) ->
      console.log 'loop_function data', data
      for c in data[data.length].correct
        if not c
          alert("You got at least one question wrong. Please try again.")
          return true
      return false

  class MouselabBlock extends Block
    type: 'mouselab-mdp'
    playerImage: 'static/images/spider.png'
    lowerMessage: 'Move with the arrow keys.'
    clickDelay: PARAMS.clickDelay
    expandOnly: PARAMS.expandOnly
    _init: ->
      _.extend(this, STRUCTURE)
      @trialCount = 0

  #  ============================== #
  #  ========= EXPERIMENT ========= #
  #  ============================== #

  img = (name) -> """<img class='display' src='static/images/#{name}.png'/>"""

  fullMessage = ""
  reset_score = new Block
    type: 'call-function'
    func: ->
      SCORE = 0

  divider = new TextBlock
    text: ->
      SCORE = 0
      "<div style='text-align: center; margin-top:100px'>Press <code>space</code> to continue.</div>"

  plain_divider = new TextBlock
    text: ->
      "<div style='text-align: center; margin-top:100px'>Press <code>space</code> to continue.</div>"

  train_intro = new ButtonBlock
    stimulus: markdown """
      ## Instructions

      In this experiment, you will play a game called *Web of Cash*, where you will
      have a chance to earn a bonus by making smart decisions. But first,
      you have to learn how to play!

      <div class="alert alert-warning">
      <strong>Quiz Warning&nbsp;</strong>
        There is a quiz at the end of the instructions. You will have only three tries
        to complete it correctly; otherwise, you will not be allowed to complete the study
        and will not earn a bonus. Please read all the instructions carefully!
      </div>
    """

  train_basic = new MouselabBlock
    blockName: 'train_basic'
    stateDisplay: 'always'
    prompt: ->
      psiturk.finishInstructions()  # can't restart once you get here
      markdown """
      ## Web of Cash

      In *Web of Cash*, you guide a money-loving spider through a spider web.
      When you land on a gray circle (a ***node***) the value of the node is
      added to your score. Your final score determines your bonus
      (not counting these practice trials).

      You can move the spider with the arrow keys, but only in the direction
      of the arrows between the nodes. Go ahead, try it out!
    """
    timeline: getTrials N_TRAIN


  train_reward = new MouselabBlock
    blockName: 'train_reward'
    stateDisplay: 'always'
    exampleOnly: true
    # lowerMessage: markdown 'Press `space` to continue.'
    timeline: [
      examples: getTrials N_TRAIN_REWARD
    ]
    prompt: ->
      diff = "Some nodes are more important than others!"
      others = "All the other nodes are worth either 1 or -1."
      explain_variance = switch PARAMS.variance
        when 'decreasing'
          if EXPERIMENT == 2
            "#{diff} The best and worst values (20 and -20) can only be found in the first four nodes of each path, right next to the spider. #{others}"
          else if EXPERIMENT == 3
            "#{diff} The values are largest (-18 to 18) at the center of the web and smallest at the edges."
        when 'increasing'
          if EXPERIMENT == 2
            "#{diff} The best and worst values (20 and -40) can only be found in the last four nodes of each, furthest from the spider. #{others}"
          else if EXPERIMENT == 3
            "#{diff} The values are largest (-18 to 18) at the edges of the web and smallest at the center."
        when 'constant'
          "Nodes can be worth -10, -5, 5, or 10. All of these are equally likely."
        else
          throw Error("bad variance")
      markdown """
        ## Node Values

        #{explain_variance}
        On average, none of the paths are better than any other path.
        
        Here are some examples of webs you might encounter.
      """

  train_hidden = new MouselabBlock
    blockName: 'train_hidden'
    stateDisplay: 'never'
    prompt: ->
      markdown """
      ## Hidden Information

      When you can see the values of each node, it's not too hard to
      take the best possible path. Unfortunately, you can't always see the
      value of the nodes. Without this information, it's hard to make good
      decisions. Try completing another round.
    """
    lowerMessage: 'Move with the arrow keys.'
    timeline: getTrials 1

  train_inspector = new MouselabBlock
    blockName: 'train_inspector'
    lowerMessage: "Click on a node to inspect it's value."
    special: 'trainClick'
    minClicks: 5
    stateDisplay: 'click'
    stateClickCost: 0
    prompt: ->
      markdown """
      ## Node Inspector

      It's hard to make good decisions when you can't see what you're doing!
      Fortunately, you have access to a ***node inspector*** which can reveal
      the value of a node. To use the node inspector, simply click on a node.

      <div class="alert alert-info">
        <strong>Note&nbsp;</strong>
        You can use the node inspector as many times as you want. However, it
        #{if PARAMS.expandOnly then "has a limited range and " else ""}
        takes some time to recharge. You can only inspect a node when it is
        highlighted. Also, you cannot inspect any nodes after moving the spider.
      </div>
    """
    # but the node inspector takes some time to work and you can only inspect one node at a time.
    timeline: getTrials N_TRAIN
    # lowerMessage: "<b>Click on the nodes to reveal their values.<b>"

  bonus_text = (long, bold=true) ->
    console.log "BONUS_TEXT", bold
    make_bold = (x) ->
      if bold then "**" + x + "**" else x
    switch PARAMS.bonusRate
      when .01
        s = make_bold "you will earn 1 cent for every $1 you make in the game."
        if long
          s += " For example, if your final score is $100, you will receive a bonus of $1.00"
        return s
      when .005
        s = make_bold "you will earn 1 cent for every $2 you make in the game."
        if long
          s += " For example, if your final score is $200, you will receive a bonus of $1.00"
        return s

  train_final = new MouselabBlock
    blockName: 'train_final'
    stateDisplay: 'click'
    stateClickCost: PARAMS.inspectCost
    prompt: ->
      markdown """
      ## Earn a Big Bonus

      Nice! You've learned how to play *Web of Cash*, and you're almost ready
      to play it for real. To make things more interesting, you will earn real
      money based on how well you play the game. Specifically,
      #{bonus_text(true)} These are the final practice rounds before your score
      starts counting towards your bonus.

      <div class="alert alert-info">
      <strong>Protip&nbsp;</strong>
        You'll get the best wage from this study if you use the node inspector
        enough to make good decisions, but not so much that you waste time.
      </div>
    """
    lowerMessage: fullMessage
    timeline: getTrials N_TRAIN

  review_variance = switch PARAMS.variance
    when 'constant'
      ', which could be anywhere in the web'
    when 'increasing'
      if EXPERIMENT == 2
        ", but only on the nodes at the end of each path"
      else if EXPERIMENT == 3
        ", but only on the nodes at the edge of the web"
    when 'decreasing'
      if EXPERIMENT == 2
        ", but only on the nodes at the beginning of each path"
      else if EXPERIMENT == 3
        ", but only on the nodes at the center of the web"

  correct_var = switch PARAMS.variance
    when 'constant' then 'Anywhere'
    when 'decreasing' then 'Only on the nodes closest to the spider'
    when 'increasing' then 'Only on the nodes furthest from the spider'

  n_quiz = 0
  quiz = new Block
    preamble: -> markdown """
      # Quiz

      Please answer the following questions before continuing.
    """
    type: 'quiz'
    numTries: 3
    onMistake: ->
      n_quiz += 1
      psiturk.recordUnstructuredData 'n_quiz', n_quiz
      saveData()

    questions: [
      "What is the best value a node can have?"
      "On which nodes might the best value appear?"
      "How many times can you use the node inspector on each round?"
      "How many points do you pay to use the node detector?"
      # "What bonus will you earn if you end the game with $100?"
    ]
    options: [
      if PARAMS.variance is 'constant' then ['$1', '$5', '$10', '$20'] else ['$3', '$9', '$18', '$20']
      ['Anywhere', 'Only on the top branch', 'Only on the left branch',
        'Only on the nodes closest to the spider', 'Only on the nodes furthest from the spider']
      ['One time', 'Three times', 'Five times', 'There is no limit']
      ['None', '$1', '$2', '$3']
      # ['$0.25', '$0.50', '$1.00', '$2.50']
    ]
    correct: [BEST_VAL, correct_var, 'There is no limit', 'None', ] # '$0.50'
    review: markdown """
      In Web of Cash, you select routes through a spider web in order to make
      the most money you can. Each location, or _node_, in the graph is worth
      some amount of money, which you collect if you pass through that node on
      your path. You can find up to #{BEST_VAL_WORD} dollars on a node#{review_variance}.
      Initially the values of the nodes are hidden, but you can
      reveal them with the _node inspector_. On each round, you can use the
      inspector as many times as you like before you move the spider. There is
      no penalty for using the node inspector, but it does take time to
      recharge. 
    """
      # To make things more fun, you will earn real money (through your
      # bonus) based on how well you play: #{bonus_text(true, false)}

  manyHot = (n, indices) ->
      x = Array(n).fill(false)
      for i in indices
        x[i] = true
      return x

  check_variance = new Block
    conditional_function: ->
      PARAMS.variance isnt 'constant'
    timeline: [
      new MouselabBlock
        blockName: 'comprehension'
        comprehension: true
        selectNodes: switch EXPERIMENT
          when 2
            switch PARAMS.variance
              when 'decreasing'
                manyHot 21, [1, 6, 11, 16]
              when 'increasing'
                manyHot 21, [5, 10, 15, 20]
          when 3
            switch PARAMS.variance
              when 'decreasing'
                manyHot 17, [1, 5, 9, 13]
              when 'increasing'
                manyHot 17, [3, 4, 7, 8, 11, 12, 15, 16]
        timeline: [
          examples:  getTrials 20
        ]
    ]

  pre_test = new ButtonBlock
    stimulus: ->
      SCORE = 100
      PASSED_INSTRUCT = true
      psiturk.recordUnstructuredData 'time_instruct', Date.now()
      markdown """
      # Training Completed

      Well done! You've completed the training phase and you're ready to
      play *Web of Cash* for real. You will have **#{N_TEST}
      rounds** to make as much money as you can.<br>
      Remember, #{bonus_text()}

      To thank you for your work so far, we'll start you off with **$100**.
      Good luck!
    """

  test = new MouselabBlock
    # minTime: 7
    blockName: 'test'
    lowerMessage: ''
    stateDisplay: 'click'
    stateClickCost: PARAMS.inspectCost
    # timeline: [TRIALS[0]]
    timeline: getTrials N_TEST
    prompt: ->
      markdown """
      # Test rounds

      Your current bonus is
      **$#{calculateBonus().toFixed(2)}**
    """

  # finish = new Block
  #   type: 'survey-text'
  #   preamble: -> markdown """
  #       # You've completed the experiment

  #       Thanks for participating. We hope you had fun! Based on your
  #       performance, you will be awarded a bonus of
  #       **$#{calculateBonus().toFixed(2)}**.

  #       Please briefly answer the questions below before you submit.
  #     """

  #   questions: [
  #     # 'What is your age?'
  #     'Can you briefly describe your strategy (one sentence)?'
  #     'Was anything confusing or hard to understand?'
  #     'Additional coments?'
  #   ]
  #   rows: 2
  #   button: 'Continue'

  timeline = [
    train_intro
    train_basic
    train_reward
    train_hidden
    train_inspector
    train_final
    quiz
    # check_variance
    pre_test
    test
    plain_divider
    # finish
  ]
  skip = getSearchParam 'skip'
  if skip?
    timeline = timeline[skip...]

  # demo_timeline = () ->
  #   if SHOW == 'test'
  #     return [test]
  #   if SHOW == 'quiz'
  #     return [quiz, check_variance, pre_test, test]
  #   if SHOW == 'comprehension'
  #     return [check_variance, pre_test, test]
  #   if WATCH_TRIALS?
  #     return [watch]
  #   else
  #     return full_timeline


  # experiment_timeline = switch
  #   when DEBUG then debug_timeline
  #   when DEMO then demo_timeline()
  #   else full_timeline
  experiment_timeline = timeline
  

  console.log 'experiment_timeline', experiment_timeline, DEMO


  # ================================================ #
  # ========= START AND END THE EXPERIMENT ========= #
  # ================================================ #

  completeHIT = ->
    if PROLIFIC
      $(window).off("beforeunload")
      $('#prolific-complete').show()
    else
      psiturk.completeHIT


  # bonus is the total score multiplied by something
  calculateBonus = ->
    if !PASSED_INSTRUCT
      return 0
    bonus = SCORE * PARAMS.bonusRate
    bonus = (Math.round (bonus * 100)) / 100  # round to nearest cent
    return Math.max(0, bonus)
  

  reprompt = null
  save_data = ->
    psiturk.saveData
      success: ->
        $('#jspsych-target').html ''
        console.log 'Data saved to psiturk server.'
        if reprompt?
          window.clearInterval reprompt
        psiturk.computeBonus('compute_bonus', completeHIT)
      error: -> prompt_resubmit


  prompt_resubmit = ->
    $('#jspsych-target').html """
      <h1>Oops!</h1>
      <p>
      Something went wrong submitting your HIT.
      This might happen if you lose your internet connection.
      Press the button to resubmit.
      </p>
      <button id="resubmit">Resubmit</button>
    """
    $('#resubmit').click ->
      $('#jspsych-target').html 'Trying to resubmit...'
      reprompt = window.setTimeout(prompt_resubmit, 10000)
      save_data()

  jsPsych.init
    display_element: $('#jspsych-target')
    timeline: experiment_timeline
    # show_progress_bar: true

    on_finish: ->
      psiturk.recordUnstructuredData 'time_end', Date.now()
      psiturk.recordUnstructuredData 'final_bonus', calculateBonus()

      if DEMO
        jsPsych.data.displayData()
      else
        save_data()

    on_data_update: (data) ->
      console.log 'data', data
      psiturk.recordTrialData data
      saveData()

