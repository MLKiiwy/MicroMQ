root = exports ? this

# Common
class XmlWrapper
	constructor:(@xml, @name, @number) ->
		@name ?= 'node'
		@number ?= 1
		@id = @name + @number

# Data
class Quizz extends XmlWrapper
	constructor: (xml) ->
		super xml, 'quizz'
		@label = @xml.find('> mq\\:label').text()
		@description = @xml.find('> mq\\:description').text()
		@background = @xml.find('> mq\\:background').attr('url')
		questions = []
		@xml.find('mq\\:question').each -> questions.push new Question($(this))
		@questions = questions
		@totalQuestions = @questions.length

class Question extends XmlWrapper
	constructor: (xml) ->
		super xml, 'question'
		@answersGiven = null
		@label = @xml.find('> mq\\:label').text()
		answers = []
		i = 1;
		@xml.find('mq\\:answer').each -> answers.push new Answer($(this), i++)
		@answers = answers

	setAnswers: (answers) ->
		@answersGiven = answers
		for answerGiven in @answersGiven
			do(answerGiven, @answers) ->
				for answer in @answers
					answer.selected = true if(answerGiven is answer.value) 


class Answer extends XmlWrapper
	constructor: (xml, n) ->
		super xml, 'answer', n
		@label = @xml.find('> mq\\:label').text()
		@value = @xml.attr('value')
		@value ?= @label
		@selected = false
		@right = (@xml.attr('right')? and @xml.attr('right') == 'true')

	isGood: ->
		return @selected == true and @right

	isWrong: ->
		return @selected == true and not @right

#Scenario
class Scenario extends XmlWrapper
	constructor: (xml) ->
		super xml, 'scenario'
		screens = {}
		i = 1;
		@xml.find('mq\\:screen').each -> 
			screen = new Screen($(this), i++)
			screens[screen.id] = screen
		@screens = screens
		@allowBackground = @xml.find('mq\\:screens').attr('allowBackground') == 'true'
		@cssGlobalClass = @xml.find('mq\\:screens').attr('cssGlobalClass')

class Binding

class Rules 

class Screen extends XmlWrapper
	constructor: (xml, n) ->
		id = xml.attr('id')
		id ?= 'screen' + n
		super xml, 'screen', n
		@id = id
		@nextClass = if @xml.attr('next')? then  @xml.attr('next') else 'mq-next'
		@validClass = if @xml.attr('valid')? then  @xml.attr('valid') else 'mq-valid'
		@answerClass = if @xml.attr('answers')? then  @xml.attr('answers') else 'answers'
		@type = @xml.attr('type')

	data: (@data) ->


	render: (@node) ->
		render = $.jqote(@xml,@data)
		return @node.append(render)

	bind: (type, func) ->
		switch type 
			when "next" 
				@node.find('.' + @nextClass).on('click',func)
			when "valid" 
				@node.find('.' + @validClass).on('click',func)
			else 

	remove: ->
		@node.html('')

	getAnswers: ->
		val = @node.find('.' + @answerClass + ':checked').val()
		if val? and typeof(val) is 'string'
			val = [val]
		else 
			val = []
		return val

	background: (globalBack) ->
		if globalBack and globalBack.length > 0
			css = 'background-image:url(\''+globalBack+'\')';
		else
			css = '' 
		@node.attr('style', css)


#Design
class Design extends XmlWrapper
	constructor: (xml) ->
		super xml, 'design'
		
	active: ->
		# For each css node include it in page
		body = $('body')
		@xml.find('mq\\:css').each ->
			newCss = '<link rel="stylesheet" type="text/css" href="' + Url.build($(this).attr('url')) + '" media="screen" />';
			body.append(newCss)

#Url object
class Url
	@init: (path) ->
		@path = path
	@build: (path) ->
		return @path + '/' + path

# Player
class root.Player 

	constructor: (@target) ->
		this.init()

	init: -> 
		@node = $(@target)
		@quizz = null
		@scenario = null
		@design = null
		@running = false
		@currentScreen = null
		@currentQuestionNumber = -1
		@answers = {}

	load: (@url) -> 
		#extract path
		urlParts = @url.split('/')
		urlParts.pop()
		Url.init(urlParts.join('/'))
		$.ajax @url,
			type: 'GET'
			dataType: 'xml'
			error: (jqXHR, textStatus, errorThrown) => @_onLoadError(jqXHR, textStatus, errorThrown)
			success: (data, textStatus, jqXHR) => @_onLoadSuccess(data, textStatus, jqXHR)

	_onLoadError: (jqXHR, textStatus, errorThrown) ->
		alert('error loading ' + @url)

	_onLoadSuccess: (data, textStatus, jqXHR) -> 
		if(@data && @running)
			@_reset()
		@quizz = new Quizz($(data).find('mq\\:quizz'))
		@scenario = new Scenario($(data).find('mq\\:scenario'))
		@design = new Design($(data).find('mq\\:design'))
		if(@running)
			@_doRun()

	run: ->
		if @running 
			return
		else 
			@running = true
			if @quizz
				@_doRun()

	next: ->
		# Analyse rules to determine next screen ?
		screenType = null
		screenType = @currentScreen.type if @currentScreen? 
		switch screenType
			when null  
				# Start screen
				this._setScreen(@scenario.screens['start'],@quizz)
			when 'start', 'question', 'answer'
				# Is it the last question ?
				if(@currentQuestionNumber is (@quizz.totalQuestions - 1) )
					this._setScreen(@scenario.screens['end'],@quizz)
				else 
					#TODO Determinate screen id
					screenId = 'question'
					@currentQuestionNumber++
					this._setScreen(@scenario.screens[screenId],@quizz.questions[@currentQuestionNumber])
			when 'end' 
				alert('fin')


	_doRun: ->
		#apply design
		@design.active()

		#apply global css if one
		if @scenario.cssGlobalClass != null
			@node.addClass(@scenario.cssGlobalClass)

		this.next()

	_setScreen: (screen, data) ->

		#TODO remove last screen
		if @currentScreen?
			@currentScreen.remove()

		@currentScreen = screen
		
		#Setting data
		screen.data(data)
		# Rendering
		screen.render(@node)
		# Background ?
		screen.background(@quizz.background)
		#Binding
		screen.bind('next',=>@_onNextClick());
		screen.bind('valid',=>@_onValidClick());

	_onNextClick: ->
		this.next()

	_onValidClick: ->
		this._saveAnswer();
		# Switch to answer screen ? 
		# TODO check bind and rules if there are not answer now ?
		screenId = 'answer'
		question = @quizz.questions[@currentQuestionNumber]
		question.setAnswers(@answers[@currentQuestionNumber])
		this._setScreen(@scenario.screens[screenId], question)

	_saveAnswer: ->
		@answers[@currentQuestionNumber] = @currentScreen.getAnswers()

	_doStop: ->
		@running = false

	_doReset: ->
		@_doStop()
		@data = null
