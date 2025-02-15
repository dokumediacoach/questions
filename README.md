# Questions

An XML based toolset to develop, test and practice multiple choice questions.

## What questions can do

With &lt;questions&gt; you can write lists of questions in XML files.
A questions XML file can be converted to an HTML file.
The HTML file can be opened in your browser to test and practice the questions.

## What questions cannot do

With &lt;questions&gt; you cannot perform a real test with the developed questions.
All generated HTML data is static. The displayed statistics (correctly answered questions) are calculated with javascript at runtime but they are not stored anywhere. If you reload the HTML file, the data is gone.
To be able to process the input data further, it would be necessary to have a webserver, even a localhost for local html files.
And of course that would require further development.

## Dependencies

To author the questions XML files with fun you need a text editor with xml schema support.\
To use the powershell script ps1/questions.ps1 for xml conversion you need Microsoft Windows.

I recommend using VS Code on a Windows machine with the Extensions PowerShell (by Microsoft) and XML (by Red Hat).

To use the questions HTML files, you need a modern browser. I use the current Mozilla Firefox.

## Get started

To get started, clone the repository from GitHub or if you don’t want to fiddle around with git [download the questions-main.zip](https://github.com/dokumediacoach/questions/archive/main.zip) and unzip it.

Open the questions-demo.html in your browser.