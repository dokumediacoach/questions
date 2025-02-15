
/*
 * global constants
 */

const languageMenuButtons = document.querySelectorAll('#language-menu button');
const langClassRegExp = /lang-[a-z]{2}/;
const previousButton = document.querySelector('#previous-button');
const nextButton = document.querySelector('#next-button');
const questionNumber = document.querySelector('#question-number');
const questionNumberAllowedSpecialKeys = ['Backspace','ArrowLeft','ArrowRight','Delete'];
const answerEvaluation = document.querySelector('#answer-evaluation');
const answerEvaluationButton = answerEvaluation.querySelector(':scope > button');
const correct = document.querySelector('#correct');
const wrong = document.querySelector('#wrong');
const showSolutionButton = document.querySelector('#show-solution-button');
const hideSolutionButton = document.querySelector('#hide-solution-button');
const evaluationCounter = document.querySelector('#evaluation-counter');
const evaluationCounterScore = document.querySelector('#evaluation-counter-score');
const boxes = document.querySelectorAll('input[type=radio], input[type=checkbox]');
const firstQuestionNr = document.body.dataset.firstQuestionNr;
const lastQuestionNr = document.body.dataset.lastQuestionNr;
const numberOfMultipleChoiceQuestions = parseInt(document.body.dataset.numberOfMultipleChoiceQuestions);
const correctAnswersCount = document.querySelector('#correct-answers-count');
const answeredCount = document.querySelector('#answered-count');
const correctAnswersPercent = document.querySelector('#correct-answers-percent');
const correctAnswersTotalPercent = document.querySelector('#correct-answers-total-percent');


/*
 * global variables
 */

var isBusy = false;
var visibleDiv = document.querySelector('main > .wrapper > .visible');
var currentMultipleChoice = document.querySelector('main > .wrapper > .question.visible .multiple-choice');
var correctAnswersCountInt = 0;
var answeredQuestionsCountInt = 0;
var correctAnswersPercentInt = 0;
var correctAnswersTotalPercentInt = 0;


/*
 * ux helper functions
 */

function enable(element) {
    if (element == null || element.classList.contains('enabled')) {
        return;
    }
    element.classList.replace('disabled', 'enabled');
}

function disable(element) {
    if (element == null || element.classList.contains('disabled')) {
        return;
    }
    element.classList.replace('enabled', 'disabled');
}

function makeVisible(element) {
    if (element == null || element.classList.contains('visible')) {
        return;
    }
    element.classList.replace('invisible', 'visible');
}

function makeInvisible(element) {
    if (element == null || element.classList.contains('invisible')) {
        return;
    }
    element.classList.replace('visible', 'invisible');
}

/** the answer evaluation button (#answer-evaluation > button) will be enabled if a box (radio or checkbox) is ticked – otherwise it will be disabled */
function evaluateAnswerEvaluationButtonEnablement() {
    var ticks = currentMultipleChoice.querySelectorAll(':scope input[type=checkbox], :scope input[type=radio]');
    var ticksTicked = false;
    for (let t of ticks) {
        if (t.checked) {
            ticksTicked = true;
            break;
        }
    }
    if (ticksTicked) {
        enable(answerEvaluationButton);
    } else {
        disable(answerEvaluationButton);
    }
}

/** makes the questions slideshow work */
function switchVisibleDiv(div) {
    if (div == null) {
        return;
    }
    visibleDiv.classList.remove('visible');
    var visualization = visibleDiv.querySelector(':scope .visualization');
    if (visualization) {
        let solution = visibleDiv.querySelector(':scope .visualization > .solution');
        if (solution.classList.contains('visible')) {
            makeInvisible(solution);
            makeInvisible(hideSolutionButton);
            makeVisible(showSolutionButton);
        }
    }
    div.classList.add('visible');
    visibleDiv = div;
    if (document.querySelector('main > .wrapper > div:has(+ .visible') == null) {
        disable(previousButton);
    } else {
        enable(previousButton);
    }
    if (document.querySelector('main > .wrapper > .visible + div') == null) {
        disable(nextButton);
    } else {
        enable(nextButton);
    }
    if (div.id == 'total-evaluation') {
        makeInvisible(answerEvaluation);
        makeInvisible(showSolutionButton);
        makeInvisible(evaluationCounter);
        return;
    } else {
        questionNumber.innerHTML = div.dataset.nr;
    }
    currentMultipleChoice = div.querySelector(':scope .multiple-choice');
    if (currentMultipleChoice) {
        makeInvisible(showSolutionButton);
        makeVisible(answerEvaluation);
        var answerEvaluationData = currentMultipleChoice.dataset.answerEvaluation;
        if (answerEvaluationData == null) {
            makeInvisible(correct);
            makeInvisible(wrong);
            evaluateAnswerEvaluationButtonEnablement();
            makeVisible(answerEvaluationButton);
            return;
        }
        makeInvisible(answerEvaluationButton);
        if (answerEvaluationData == "correct") {
            makeInvisible(wrong);
            makeVisible(correct);
        } else if (answerEvaluationData == "wrong") {
            makeInvisible(correct);
            makeVisible(wrong);
        }
        makeVisible(evaluationCounter);
        return;
    }
    visualization = div.querySelector(':scope .visualization');
    if (visualization) {
        makeInvisible(answerEvaluation);
        makeVisible(showSolutionButton);
        makeInvisible(evaluationCounter);
        return;
    }
}


/*
 * event listeners
 */

/* for: #language-menu button */
for (let button of languageMenuButtons) {
    button.addEventListener('click', (e) => {
        if (isBusy || button.classList.contains('active')) {
            return;
        }
        isBusy = true;
        selectedLang = button.textContent;
        for (let item of document.body.classList) {
            if (langClassRegExp.test(item)) {
                document.body.classList.remove(item);
                break;
            }
        }
        document.body.classList.add('lang-' + selectedLang);
        for (let lmb of languageMenuButtons) {
            if (lmb.classList.contains('active')) {
                lmb.classList.remove('active');
                break;
            }
        }
        button.classList.add('active');
        isBusy = false;
    }, false);
}

/* for: #answer-evaluation > button */
answerEvaluationButton.addEventListener('click', (e) => {
    if (isBusy || currentMultipleChoice == null || !answerEvaluationButton.checkVisibility() || answerEvaluationButton.classList.contains('disabled')) {
        return;
    }
    isBusy = true;
    var options = currentMultipleChoice.querySelectorAll(':scope .option');
    var answerIsCorrect = true;
    for (let option of options) {
        var optionCorrect = option.classList.contains('correct');
        var tick = option.querySelector(':scope input[type=radio], :scope input[type=checkbox]');
        if (tick.checked && optionCorrect) {
            option.classList.add('answer-correct');
        } else if (tick.checked && !optionCorrect) {
            option.classList.add('answer-wrong');
            answerIsCorrect = false;
        } else if (optionCorrect && !tick.checked) {
            option.classList.add('answer-missed');
            answerIsCorrect = false;
        }
    }
    makeInvisible(answerEvaluationButton);
    if (answerIsCorrect) {
        correctAnswersCountInt++;
        answeredQuestionsCountInt++;
        makeVisible(correct);
        currentMultipleChoice.dataset.answerEvaluation = "correct"
    } else {
        answeredQuestionsCountInt++;
        makeVisible(wrong);
        currentMultipleChoice.dataset.answerEvaluation = "wrong"
    }
    correctAnswersPercentInt = correctAnswersCountInt / answeredQuestionsCountInt * 100;
    correctAnswersPercentInt = correctAnswersPercentInt.toFixed();
    evaluationCounterScore.innerHTML = correctAnswersCountInt + ' / ' + answeredQuestionsCountInt + ' (' + correctAnswersPercentInt + ' %)';
    makeVisible(evaluationCounter);
    correctAnswersTotalPercentInt = correctAnswersCountInt / numberOfMultipleChoiceQuestions * 100;
    correctAnswersTotalPercentInt = correctAnswersTotalPercentInt.toFixed();
    correctAnswersCount.innerHTML = correctAnswersCountInt;
    answeredCount.innerHTML = answeredQuestionsCountInt;
    correctAnswersPercent.innerHTML = correctAnswersPercentInt + ' %';
    correctAnswersTotalPercent.innerHTML = correctAnswersTotalPercentInt + ' %';
    isBusy = false;
}, false);

/* for: #show-solution-button */
showSolutionButton.addEventListener('click', (e) => {
    let solution = visibleDiv.querySelector(':scope .visualization > .solution');
    if (isBusy || solution == null || !showSolutionButton.checkVisibility()) {
        return;
    }
    isBusy = true;
    makeVisible(solution);
    solution.scrollIntoView({behavior: "smooth"});
    makeInvisible(showSolutionButton);
    makeVisible(hideSolutionButton);
    isBusy = false;
}, false);

/* for: #hide-solution-button */
hideSolutionButton.addEventListener('click', (e) => {
    let solution = visibleDiv.querySelector(':scope .visualization > .solution');
    if (isBusy || solution == null || !hideSolutionButton.checkVisibility()) {
        return;
    }
    isBusy = true;
    makeInvisible(solution);
    makeInvisible(hideSolutionButton);
    makeVisible(showSolutionButton);
    isBusy = false;
}, false);

/* for: #previous-button */
previousButton.addEventListener('click', (e) => {
    if (isBusy || previousButton.classList.contains('disabled')) {
        return;
    }
    isBusy = true;
    var previousDiv = document.querySelector('main > .wrapper > div:has(+ .visible');
    if (previousDiv == null) {
        previousButton.classList.replace('enabled', 'disabled');
        return;
    }
    switchVisibleDiv(previousDiv)
    isBusy = false;
}, false);

/* for: #next-button */
nextButton.addEventListener('click', (e) => {
    if (isBusy || nextButton.classList.contains('disabled')) {
        return;
    }
    isBusy = true;
    var nextDiv = document.querySelector('main > .wrapper > .visible + div');
    if (nextDiv == null) {
        nextButton.classList.replace('enabled', 'disabled');
        return;
    }
    switchVisibleDiv(nextDiv)
    isBusy = false;
}, false);

/* for: #question-number */
questionNumber.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
        qNr = questionNumber.innerHTML;
        targetQuestion = document.querySelector('.question[data-nr="' + qNr + '"]');
        if (targetQuestion) {
            switchVisibleDiv(targetQuestion);
        } else if (visibleDiv.id == 'total-evaluation') {
            questionNumber.innerHTML = lastQuestionNr;
        } else {
            questionNumber.innerHTML = visibleDiv.dataset.nr;
        }
        questionNumber.blur();
        e.preventDefault();
    } else if (e.key == 'ArrowDown') {
        questionNumber.innerHTML = firstQuestionNr;
        let selection = document.getSelection();
        selection.selectAllChildren(questionNumber);
        selection.collapseToEnd();
        e.preventDefault();
    } else if (e.key == 'ArrowUp') {
        questionNumber.innerHTML = lastQuestionNr;
        let selection = document.getSelection();
        selection.selectAllChildren(questionNumber);
        selection.collapseToEnd();
        e.preventDefault();
    } else if (e.key == 'Escape') {
        questionNumber.blur();
    } else if (!questionNumberAllowedSpecialKeys.includes(e.key) && isNaN(e.key)) {
        e.preventDefault();
    } else {
        e.stopPropagation();
    }
}, false);

/* for: input[type=radio], input[type=checkbox] */
for (let box of boxes) {
    box.addEventListener('click', (e) => {
        if (isBusy || currentMultipleChoice == null) {
            return;
        }
        isBusy = true;
        evaluateAnswerEvaluationButtonEnablement()
        isBusy = false;
    }, false);
}


/*
 * keyboard control
 */

/** helper function to click a multiple choice answer by its position */
function clickBox(position) {
    if (currentMultipleChoice == null || currentMultipleChoice.dataset.answerEvaluation) {
        return;
    }
    let selector = ':scope > div.option:nth-child(' + position + ') input';
    let box = currentMultipleChoice.querySelector(selector);
    if (box == null) {
        return;
    }
    box.click();
}

/* keydown event listener */
document.body.addEventListener('keydown', (e) => {
    switch (e.key) {
        case 'a':
            clickBox(1);
            break;
        case 'b':
            clickBox(2);
            break;
        case 'c':
            clickBox(3);
            break;
        case 'd':
            clickBox(4);
            break;
        case 'e':
            clickBox(5);
            break;
        case 'f':
            clickBox(6);
            break;
        case 'g':
            clickBox(7);
            break;
        case 'h':
            clickBox(8);
            break;
        case 'i':
            clickBox(9);
            break;
        case 'j':
            clickBox(10);
            break;
        case 'k':
            clickBox(11);
            break;
        case 'l':
            clickBox(12);
            break;
        case '?':
            answerEvaluationButton.click();
            break;
        case '!':
            showSolutionButton.click();
            break;
        case 'ArrowLeft':
            previousButton.click();
            break;
        case 'ArrowRight':
            nextButton.click();
            break;
        default:
            break;
    }
}, false);


/* by default browser may store input status ( checked ) over page reloads ( pressing [F5] )
   
   this function therefore clears all boxes ( input[type=radio], input[type=checkbox] ) when page is loaded */
document.addEventListener('DOMContentLoaded', function() {
    boxes.forEach( (input) => {
        input.checked = false
    }
)}, false);