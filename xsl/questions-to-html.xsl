<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    
    <xsl:output method="html"
        doctype-system="about:legacy-compat"
        encoding="UTF-8"
        indent="no"/>
    
    <!-- $questionsOrder = /(nr|renumber)/
         "nr" (default) for sorting by /questions/question/@nr
         "renumber" for document order and new numbering of /questions/question
                    applies to random collections of questions that are only identified by /questions/question/@guid
    -->
    <xsl:param name="questionsOrder" select="'nr'"/>
    
    <!-- $language = /[a-z]{2}(\|[a-z]{2})*/
         holds the request for (output) language(s) of questions
    -->
    <xsl:param name="language">
        <xsl:choose>
            <xsl:when test="/questions/@language">
                <xsl:value-of select="/questions/@language"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="/questions/@xml:lang"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:param>

    <!-- per default, questions xml files and the html files derived from them are
         in the root folder of a questions environment (originally named questions)
         
         for loading css and js in html browser there are subfolders
    -->
    <xsl:param name="cssPath" select="'css/questions.css'"/>
    <xsl:param name="jsPath" select="'js/questions.js'"/>


    <!-- language variables are used throughout the whole stylesheet
    
         boolean $multilanguage - is there more than one language in output?
         –
         controls if language menu is displayed
         also used in definition of $mainLanguage hereunder
    -->
    <xsl:variable name="multilanguage" select="contains($language,'|')"/>
    
    <!-- $mainLanguage = /[a-z]{2}/
         -
         the output of a questions is always initiated from the question's main language which also means that
         only questions with a main language in input xml will be present in output
         
         if there is only one single language than it is of course also the main language
    -->
    <xsl:variable name="mainLanguage">
        <xsl:choose>
            <!-- if requested $language is a list of langcodes /[a-z]{2}(\|[a-z]{2})+/ or easier
                 if contains($language,'|') … -->
            <xsl:when test="$multilanguage">
                <!-- … then the first in a list of langcodes in $language defines the main language -->
                <xsl:value-of select="substring-before($language,'|')"/>
            </xsl:when>
            <xsl:otherwise>
                <!-- else the single langcode in $language defines the $mainLanguage -->
                <xsl:value-of select="$language"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>

    <!-- the rest of this stylesheet is only for xslt geeks;
         I found some of it quite cumbersome to develop
         because of the limitations of xslt 1.0
         - maybe I put some more comments in later but
           I think the stylesheet is already too long ...
           -->
    <xsl:template match="/">
        <html>
            <head>
                <title>
                    <xsl:value-of select="/questions/@topic"/>
                </title>
                <meta charset="UTF-8" />
                <link href="{$cssPath}" rel="stylesheet" />
                <style>
                    <xsl:call-template name="addLangVisibilityStyle">
                        <xsl:with-param name="elementName" select="'div'"/>
                    </xsl:call-template>
                    <xsl:call-template name="addLangVisibilityStyle">
                        <xsl:with-param name="elementName" select="'span'"/>
                    </xsl:call-template>
                </style>
            </head>
            <xsl:apply-templates select="/questions"/>
        </html>
    </xsl:template>

    <xsl:template name="addLangVisibilityStyle">
        <xsl:param name="elementName"/>
        <xsl:call-template name="addLangVisibilitySelector">
            <xsl:with-param name="elementName" select="$elementName"/>
            <xsl:with-param name="isFirst" select="true()"/>
        </xsl:call-template>
        <xsl:text>{display:</xsl:text>
        <xsl:choose>
            <xsl:when test="$elementName='div'">block</xsl:when>
            <xsl:otherwise>inline</xsl:otherwise>
        </xsl:choose>
        <xsl:text>;}</xsl:text>
    </xsl:template>

    <xsl:template name="addLangVisibilitySelector">
        <xsl:param name="elementName"/>
        <xsl:param name="languageString" select="$language"/>
        <xsl:param name="isFirst" select="false()"/>
        <xsl:variable name="recurse" select="contains($languageString,'|')"/>
        <xsl:variable name="currentLanguage">
            <xsl:choose>
                <xsl:when test="$recurse">
                    <xsl:value-of select="substring-before($languageString,'|')"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="$languageString"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:if test="not($isFirst)">,</xsl:if>
        <xsl:value-of select="concat('body.lang-',$currentLanguage,' ',$elementName,'.lang-',$currentLanguage)"/>
        <xsl:if test="$recurse">
            <xsl:call-template name="addLangVisibilitySelector">
                <xsl:with-param name="elementName" select="$elementName"/>
                <xsl:with-param name="languageString" select="substring-after($languageString,'|')"/>
            </xsl:call-template>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="questions">
        <xsl:variable name="totalNumberOfQuestions" select="count(question[lang($mainLanguage)])"/>
        <xsl:variable name="numberOfMultipleChoiceQuestions" select="count(question[lang($mainLanguage)][multiple-choice])"/>
        <xsl:variable name="lastQuestionNr">
            <xsl:choose>
                <xsl:when test="$questionsOrder='renumber'">
                    <xsl:value-of select="$totalNumberOfQuestions"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:for-each select="question[lang($mainLanguage)]">
                        <xsl:sort select="@nr" data-type="number"/>
                        <xsl:if test="position()=last()">
                            <xsl:value-of select="@nr"/>
                        </xsl:if>
                    </xsl:for-each>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="firstQuestionNr">
            <xsl:choose>
                <xsl:when test="$questionsOrder='renumber'">
                    <xsl:value-of select="1"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:for-each select="question[lang($mainLanguage)]">
                        <xsl:sort select="@nr" data-type="number"/>
                        <xsl:if test="position()=1">
                            <xsl:value-of select="@nr"/>
                        </xsl:if>
                    </xsl:for-each>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="firstQuestionType">
            <xsl:choose>
                <xsl:when test="$questionsOrder='renumber' and question[lang($mainLanguage)][1]/multiple-choice">
                    <xsl:value-of select="'multipleChoice'"/>
                </xsl:when>
                <xsl:when test="$questionsOrder='renumber'">
                    <xsl:value-of select="'visualization'"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:for-each select="question[lang($mainLanguage)]">
                        <xsl:sort select="@nr" data-type="number"/>
                        <xsl:if test="position()=1">
                            <xsl:choose>
                                <xsl:when test="./multiple-choice">multipleChoice</xsl:when>
                                <xsl:otherwise>visualization</xsl:otherwise>
                            </xsl:choose>
                        </xsl:if>
                    </xsl:for-each>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="answerEvaluationClass">
            <xsl:choose>
                <xsl:when test="$firstQuestionType='multipleChoice'">visible</xsl:when>
                <xsl:otherwise>invisible</xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="showSolutionClass">
            <xsl:choose>
                <xsl:when test="$firstQuestionType='multipleChoice'">invisible</xsl:when>
                <xsl:otherwise>visible</xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <body id="questions" class="lang-{$mainLanguage}"
              data-first-question-nr="{$firstQuestionNr}"
              data-first-question-type="{$firstQuestionType}"
              data-last-question-nr="{$lastQuestionNr}"
              data-total-number-of-questions="{$totalNumberOfQuestions}"
              data-number-of-multiple-choice-questions="{$numberOfMultipleChoiceQuestions}">
            <div class="wrapper">
                <header>
                    <div class="wrapper">
                        <h1>
                            <xsl:value-of select="/questions/@topic"/>
                        </h1>
                        <xsl:if test="$multilanguage">
                            <nav id="language-menu">
                                <xsl:call-template name="addLanguageMenuButton">
                                    <xsl:with-param name="isActive" select="true()"/>
                                </xsl:call-template>
                            </nav>
                        </xsl:if>
                    </div>
                </header>
                <main>
                    <div class="wrapper">
                        <xsl:choose>
                            <xsl:when test="$questionsOrder='renumber'">
                                <xsl:apply-templates select="question[lang($mainLanguage)]"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:apply-templates select="question[lang($mainLanguage)]">
                                    <xsl:sort select="@nr" data-type="number"/>
                                </xsl:apply-templates>
                            </xsl:otherwise>
                        </xsl:choose>
                        <div id="total-evaluation">
                            <h2 id="total-evaluation-heading">
                                <xsl:call-template name="getI18nResourceStringSpans">
                                    <xsl:with-param name="stringID" select="'totalEvaluationHeading'"/>
                                </xsl:call-template>
                            </h2>
                            <div class="grid">
                                <div id="correct-answers-count-label">
                                    <xsl:call-template name="getI18nResourceStringSpans">
                                        <xsl:with-param name="stringID" select="'correctAnswersCountLabel'"/>
                                    </xsl:call-template>
                                </div>
                                <div id="correct-answers-count">0</div>
                                <div id="answered-count-label">
                                    <xsl:call-template name="getI18nResourceStringSpans">
                                        <xsl:with-param name="stringID" select="'answeredCountLabel'"/>
                                    </xsl:call-template>
                                </div>
                                <div id="answered-count">0</div>
                                <div id="number-of-questions-label">
                                    <xsl:call-template name="getI18nResourceStringSpans">
                                        <xsl:with-param name="stringID" select="'numberOfQuestionsLabel'"/>
                                    </xsl:call-template>
                                </div>
                                <div>
                                    <xsl:value-of select="$numberOfMultipleChoiceQuestions"/>
                                </div>
                                <div id="correct-answers-percent-label">
                                    <xsl:call-template name="getI18nResourceStringSpans">
                                        <xsl:with-param name="stringID" select="'correctAnswersPercentLabel'"/>
                                    </xsl:call-template>
                                </div>
                                <div id="correct-answers-percent">0 %</div>
                                <div id="correct-answers-total-percent-label">
                                    <xsl:call-template name="getI18nResourceStringSpans">
                                        <xsl:with-param name="stringID" select="'correctAnswersTotalPercentLabel'"/>
                                    </xsl:call-template>
                                </div>
                                <div id="correct-answers-total-percent">0 %</div>
                            </div>
                        </div>
                    </div>
                </main>
                <footer>
                    <div class="wrapper">
                        <div id="footer-left">
                            <div id="answer-evaluation" class="{$answerEvaluationClass}">
                                <button type="button" class="visible disabled" id="answer-evaluation-button">
                                    <xsl:call-template name="getI18nResourceStringSpans">
                                        <xsl:with-param name="stringID" select="'answerEvaluationButton'"/>
                                    </xsl:call-template>
                                </button>
                                <div id="correct" class="invisible">
                                    <xsl:call-template name="getI18nResourceStringSpans">
                                        <xsl:with-param name="stringID" select="'correctAnswer'"/>
                                    </xsl:call-template>
                                </div>
                                <div id="wrong" class="invisible">
                                    <xsl:call-template name="getI18nResourceStringSpans">
                                        <xsl:with-param name="stringID" select="'wrongAnswer'"/>
                                    </xsl:call-template>
                                </div>
                            </div>
                            <button type="button" id="show-solution-button" class="{$showSolutionClass}">
                                <xsl:call-template name="getI18nResourceStringSpans">
                                    <xsl:with-param name="stringID" select="'showSolutionButton'"/>
                                </xsl:call-template>
                            </button>
                            <button type="button" id="hide-solution-button" class="invisible">
                                <xsl:call-template name="getI18nResourceStringSpans">
                                    <xsl:with-param name="stringID" select="'hideSolutionButton'"/>
                                </xsl:call-template>
                            </button>
                            <div id="evaluation-counter" class="invisible">
                                <xsl:call-template name="getI18nResourceStringSpans">
                                    <xsl:with-param name="stringID" select="'evaluationCounterLabel'"/>
                                </xsl:call-template>
                                <xsl:text> </xsl:text>
                                <span id="evaluation-counter-score"></span>
                            </div>
                        </div>
                        <nav id="previous-next-menu">
                            <button type="button" id="previous-button" class="disabled">🡄</button>
                            <div id="question-selector">
                                <div id="question-number" contenteditable="true">
                                    <xsl:value-of select="$firstQuestionNr"/>
                                </div>
                                <div id="questions-total">
                                    <xsl:text>/ </xsl:text>
                                    <xsl:value-of select="$lastQuestionNr"/>
                                </div>
                            </div>
                            <button type="button" id="next-button" class="enabled">🡆</button>
                        </nav>
                    </div>
                </footer>
            </div>
            <script src="{$jsPath}"></script>
        </body>
    </xsl:template>

    <xsl:template name="getI18nResourceStringSpans">
        <xsl:param name="stringID"/>
        <xsl:param name="languageString" select="$language"/>
        <xsl:variable name="recurse" select="contains($languageString,'|')"/>
        <xsl:variable name="currentLanguage">
            <xsl:choose>
                <xsl:when test="$recurse">
                    <xsl:value-of select="substring-before($languageString,'|')"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="$languageString"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <span class="langswitch lang-{$currentLanguage}">
            <xsl:value-of select="document('i18n-resource-strings.xml')/strings/string[@id=$stringID]/lang[@xml:lang=$currentLanguage]"/>
        </span>
        <xsl:if test="$recurse">
            <xsl:call-template name="getI18nResourceStringSpans">
                <xsl:with-param name="stringID" select="$stringID"/>
                <xsl:with-param name="languageString" select="substring-after($languageString,'|')"/>
            </xsl:call-template>
        </xsl:if>
    </xsl:template>

    <xsl:template name="addLanguageMenuButton">
        <xsl:param name="languageString" select="$language"/>
        <xsl:param name="isActive" select="false()"/>
        <xsl:variable name="recurse" select="contains($languageString,'|')"/>
        <xsl:variable name="currentLanguage">
            <xsl:choose>
                <xsl:when test="$recurse">
                    <xsl:value-of select="substring-before($languageString,'|')"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="$languageString"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <button type="button" id="{$currentLanguage}-button">
            <xsl:if test="$isActive">
                <xsl:attribute name="class">active</xsl:attribute>
            </xsl:if>
            <xsl:value-of select="$currentLanguage"/>
        </button>
        <xsl:if test="$recurse">
            <xsl:call-template name="addLanguageMenuButton">
                <xsl:with-param name="languageString" select="substring-after($languageString,'|')"/>
            </xsl:call-template>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="question">
        <xsl:variable name="visibleClass">
            <xsl:if test="position() = 1">
                <xsl:text> visible</xsl:text>
            </xsl:if>
        </xsl:variable>
        <xsl:variable name="outputQuestionNr">
            <xsl:choose>
                <xsl:when test="$questionsOrder='renumber'">
                    <xsl:value-of select="position()"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="@nr"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <div class="question{$visibleClass}" data-nr="{$outputQuestionNr}">
            <h2>
                <xsl:call-template name="getI18nResourceStringSpans">
                    <xsl:with-param name="stringID" select="'questionHeading'"/>
                </xsl:call-template>
                <xsl:text> </xsl:text>
                <xsl:value-of select="$outputQuestionNr"/>
            </h2>
            <xsl:apply-templates>
                <xsl:with-param name="questionNr" select="@nr"/>
                <xsl:with-param name="questionGuid" select="@guid"/>
            </xsl:apply-templates>
        </div>
    </xsl:template>
    
    <xsl:template match="intro">
        <xsl:param name="questionNr"/>
        <xsl:param name="questionGuid"/>
        <div class="intro">
            <xsl:call-template name="getLangswitchContent">
                <xsl:with-param name="questionNr" select="$questionNr"/>
                <xsl:with-param name="questionGuid" select="$questionGuid"/>
                <xsl:with-param name="element" select="'intro'"/>
            </xsl:call-template>
        </div>
    </xsl:template>
    
    <xsl:template match="visualization">
        <xsl:param name="questionNr"/>
        <xsl:param name="questionGuid"/>
        <div class="visualization">
            <div class="task">
                <xsl:call-template name="getLangswitchContent">
                    <xsl:with-param name="questionNr" select="$questionNr"/>
                    <xsl:with-param name="questionGuid" select="$questionGuid"/>
                    <xsl:with-param name="element" select="'task'"/>
                </xsl:call-template>
            </div>
            <div class="solution invisible">
                <h3 class="solution-heading">
                    <xsl:call-template name="getI18nResourceStringSpans">
                        <xsl:with-param name="stringID" select="'solutionHeading'"/>
                    </xsl:call-template>
                </h3>
                <xsl:call-template name="getLangswitchContent">
                    <xsl:with-param name="questionNr" select="$questionNr"/>
                    <xsl:with-param name="questionGuid" select="$questionGuid"/>
                    <xsl:with-param name="element" select="'solution'"/>
                </xsl:call-template>
            </div>
        </div>
    </xsl:template>
    
    <xsl:template match="multiple-choice">
        <xsl:param name="questionNr"/>
        <xsl:param name="questionGuid"/>
        <xsl:variable name="correctChoices" select="count(option[@correct='true'])"/>
        <xsl:variable name="type">
            <xsl:choose>
                <xsl:when test="$correctChoices=1">radio</xsl:when>
                <xsl:otherwise>checkbox</xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <div class="multiple-choice" data-correct-choices="{$correctChoices}">
            <xsl:apply-templates select="option">
                <xsl:with-param name="questionNr" select="$questionNr"/>
                <xsl:with-param name="questionGuid" select="$questionGuid"/>
                <xsl:with-param name="type" select="$type"/>
                <xsl:with-param name="mcID" select="generate-id()"/>
            </xsl:apply-templates>
        </div>
    </xsl:template>
    
    <xsl:template match="option">
        <xsl:param name="questionNr"/>
        <xsl:param name="questionGuid"/>
        <xsl:param name="type"/>
        <xsl:param name="mcID"/>
        <xsl:variable name="position" select="position()"/>
        <xsl:variable name="correctClass">
            <xsl:if test="@correct='true'">
                <xsl:value-of select="' correct'"/>
            </xsl:if>
        </xsl:variable>
        <div class="option{$correctClass}">
            <label>
                <input type="{$type}">
                    <xsl:if test="$type='radio'">
                        <xsl:attribute name="name">
                            <xsl:value-of select="$mcID"/>
                        </xsl:attribute>
                    </xsl:if>
                </input>
                <span>
                    <xsl:call-template name="getLangswitchContent">
                        <xsl:with-param name="questionNr" select="$questionNr"/>
                        <xsl:with-param name="questionGuid" select="$questionGuid"/>
                        <xsl:with-param name="element" select="'option'"/>
                        <xsl:with-param name="elementPosition" select="$position"/>
                    </xsl:call-template>
                </span>
            </label>
        </div>
    </xsl:template>

    <xsl:template name="getLangswitchContent">
        <xsl:param name="questionNr"/>
        <xsl:param name="questionGuid"/>
        <xsl:param name="element"/>
        <xsl:param name="elementPosition" select="1"/>
        <xsl:param name="languageString" select="$language"/>
        <xsl:variable name="recurse" select="contains($languageString,'|')"/>
        <xsl:variable name="currentLanguage">
            <xsl:choose>
                <xsl:when test="$recurse">
                    <xsl:value-of select="substring-before($languageString,'|')"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="$languageString"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="elementName">
            <xsl:choose>
                <xsl:when test="$element='option'">span</xsl:when>
                <xsl:otherwise>div</xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:element name="{$elementName}">
            <xsl:attribute name="class">
                <xsl:value-of select="concat('langswitch lang-',$currentLanguage)"/>
            </xsl:attribute>
            <xsl:choose>
                <xsl:when test="$element='intro' and $questionGuid">
                    <xsl:apply-templates select="/questions/question[@guid=$questionGuid][lang($currentLanguage)]/intro/node()"/>
                </xsl:when>
                <xsl:when test="$element='intro'">
                    <xsl:apply-templates select="/questions/question[@nr=$questionNr][lang($currentLanguage)]/intro/node()"/>
                </xsl:when>
                <xsl:when test="$element='task' and $questionGuid">
                    <xsl:apply-templates select="/questions/question[@guid=$questionGuid][lang($currentLanguage)]/visualization/task/node()"/>
                </xsl:when>
                <xsl:when test="$element='task'">
                    <xsl:apply-templates select="/questions/question[@nr=$questionNr][lang($currentLanguage)]/visualization/task/node()"/>
                </xsl:when>
                <xsl:when test="$element='solution' and $questionGuid">
                    <xsl:apply-templates select="/questions/question[@guid=$questionGuid][lang($currentLanguage)]/visualization/solution/node()"/>
                </xsl:when>
                <xsl:when test="$element='solution'">
                    <xsl:apply-templates select="/questions/question[@nr=$questionNr][lang($currentLanguage)]/visualization/solution/node()"/>
                </xsl:when>
                <xsl:when test="$element='option' and $questionGuid">
                    <xsl:apply-templates select="/questions/question[@guid=$questionGuid][lang($currentLanguage)]/multiple-choice/option[$elementPosition]/node()"/>
                </xsl:when>
                <xsl:when test="$element='option'">
                    <xsl:apply-templates select="/questions/question[@nr=$questionNr][lang($currentLanguage)]/multiple-choice/option[$elementPosition]/node()"/>
                </xsl:when>
            </xsl:choose> 
        </xsl:element>
        <xsl:if test="$recurse">
            <xsl:call-template name="getLangswitchContent">
                <xsl:with-param name="questionNr" select="$questionNr"/>
                <xsl:with-param name="questionGuid" select="$questionGuid"/>
                <xsl:with-param name="element" select="$element"/>
                <xsl:with-param name="elementPosition" select="$elementPosition"/>
                <xsl:with-param name="languageString" select="substring-after($languageString,'|')"/>
            </xsl:call-template>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="h">
        <h3>
            <xsl:apply-templates/>
        </h3>
    </xsl:template>
    
    <xsl:template match="codeblock">
        <div class="codeblock">
            <pre>
                <code>
                    <xsl:apply-templates/>
                </code>
            </pre>
        </div>
    </xsl:template>
    
    <xsl:template match="uppercase">
        <span class="uppercase">
            <xsl:apply-templates/>
        </span>
    </xsl:template>
    
    <xsl:template match="p|code|em|strong|ul|ol|li">
        <xsl:element name="{local-name()}">
            <xsl:apply-templates/>
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="br|img">
        <xsl:element name="{local-name()}">
            <xsl:copy-of select="@*"/>
        </xsl:element>
    </xsl:template>
    
</xsl:stylesheet>