# DartPDF privacy information

_Last updated: 14 June 2026_

This modified copy of DartPDF is a PDF viewer and editor. This page describes
how it handles your information.

## What we collect

The app has no analytics, advertising, accounts, or document-processing
backend. It does not send PDF contents or recognized text to a server.

## Your documents and OCR

PDFs you open, edit, annotate, sign, or save are processed **locally on your
device only**. Their contents are never uploaded to us or to any third party.
When you choose to share or export a document, it goes only to the destination
you pick (for example, another app via the system share sheet, or a file
location you select).

OCR also runs locally. Native builds download OCR model files from this
project's public repository on first use and cache them on the device. The web
build copies the bundled models into the web app. Recognition runs locally;
your PDF pages and recognized text are not sent to an OCR server.

When update checks run, the app requests public release metadata from GitHub.
The developer-release notice also reads public release and commit metadata.
These requests do not include document contents or require a GitHub login.
GitHub may receive normal connection metadata, such as your IP address.

## Device permissions

DartPDF requests access to files only so it can open the PDFs you choose and
save your changes back. This access is used solely to perform the action you
requested and for no other purpose.

When you digitally sign a PDF, the private-key and certificate files you
choose are read into memory only. The private key is not saved in preferences,
embedded in the PDF, uploaded, or sent to a server; only the public certificate
chain and cryptographic signature are written to the signed document.

## App preferences

Settings such as your theme, recent-file list, and tool styles are stored
locally on your device using the operating system's standard preference
storage. They never leave your device and are removed when you uninstall the
app or clear its data.

## Third parties

The app does not embed analytics, advertising, or tracking SDKs. GitHub serves
release metadata and OCR model files; when you open an external link, that
destination's privacy policy applies.

## Children

DartPDF is a general-purpose productivity tool and does not knowingly collect
any information from anyone, including children.

## Changes to this policy

If this policy changes, we will update the "Last updated" date above and post
the revised policy at the same URL.

## Contact

Questions about this policy: https://github.com/tesonepdf/dart-pdf/issues
