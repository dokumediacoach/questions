#culture="de-DE"
ConvertFrom-StringData @'
    schemaReadingInfo = XML-Schema-Datei wird gelesen ...
    schemaValidationError = Fehler beim Lesen der XML-Schema-Datei. Abbruch der Ausführung.
    xmlReadingInfo = XML-Datei wird gelesen ...
    checkingLanguagesInfo = Die Spracheinstellungen der questions werden überprüft ...
    noMultiLanguageError = Spracheinstellungen für die Übersetzung nicht gefunden. Definiere sie in /questions/@language als |-getrennte Liste von zwei Zeichen langen Sprachcodes, wobei der erste Sprachcode die Hauptsprache ist, von der jede Verarbeitung der questions initialisiert wird.
    languageNotUniqueError = Sprache nicht einzigartig in /questions/@language
    noMainLanguageQuestionsError = Keine question in der Hauptsprache gefunden. Überprüfe die Sprachdefinition in /questions/@language - der erste Sprachcode in der |-getrennten Liste ist die Hauptsprache, von der jede Verarbeitung der questions initialisiert wird.
    translationMissingError = Übersetzung fehlt für question nr:
    adaptingCodeblocksInfo = Texte von codeblocks in questions werden angepasst ...
    loadingXsltInfo = XSLT-Stylesheet wird geladen ...
    executingXsltTransformationInfo = XSLT-Transformation zu HTML wird ausgeführt ...
    htmlCreationSuccessInfo = Die HTML-Datei wurde erfolgreich erstellt:
    xmlCreationSuccessInfo = Die XML-Datei wurde erfolgreich erstellt:
'@