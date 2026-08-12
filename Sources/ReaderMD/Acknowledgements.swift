import Foundation

/// The open-source and third-party notices shown in the About window.
///
/// Embedded as a string literal rather than a bundled resource on purpose. The
/// MIT and BSD licenses below require their notices to travel with every copy
/// of the app, and a resource file can be dropped by a change to the packaging
/// scripts without anything failing to build — which is exactly how these
/// notices came to be missing from the shipped bundle in the first place.
/// Compiled into the binary, they cannot go missing.
///
/// When bumping a vendored library in `Resources/Renderer`, update the version
/// and the license text here in the same commit. `AcknowledgementsTests`
/// checks that every vendored library is still named here.
enum Acknowledgements {
    /// Every vendored library that must appear in the notices, with the version
    /// currently in `Resources/Renderer`.
    static let vendoredLibraries = [
        "markdown-it 14.3.0",
        "markdown-it-footnote 4.0.0",
        "Mermaid 11.16.0",
        "KaTeX 0.16.47",
        "highlight.js 11.11.1"
    ]

    static let text = #"""
    ReaderMD is open source under the Apache License, Version 2.0.

    Copyright 2026 Adam Jesionkiewicz and ReaderMD contributors.
    Originally created by Adam Jesionkiewicz.

    The complete Apache-2.0 license and project NOTICE are included in every
    application bundle under Contents/Resources/Legal and in the source
    repository at https://github.com/ashtree74/ReaderMD.


    ════════════════════════════════════════════════════════════════════════

    ReaderMD sets your documents with a handful of open-source libraries,
    bundled as local copies so rendering never needs a network connection.

    Their licenses require that the copyright notices and license texts below
    travel with every copy of this app. They are reproduced here in full.


    ════════════════════════════════════════════════════════════════════════

    markdown-it 14.3.0 — MIT License
    https://github.com/markdown-it/markdown-it

    Copyright (c) 2014 Vitaly Puzrin, Alex Kocharin.

    Permission is hereby granted, free of charge, to any person
    obtaining a copy of this software and associated documentation
    files (the "Software"), to deal in the Software without
    restriction, including without limitation the rights to use,
    copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the
    Software is furnished to do so, subject to the following
    conditions:

    The above copyright notice and this permission notice shall be
    included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
    OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
    NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
    HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
    OTHER DEALINGS IN THE SOFTWARE.


    ════════════════════════════════════════════════════════════════════════

    markdown-it-footnote 4.0.0 — MIT License
    https://github.com/markdown-it/markdown-it-footnote

    Copyright (c) 2014-2015 Vitaly Puzrin, Alex Kocharin.

    Permission is hereby granted, free of charge, to any person
    obtaining a copy of this software and associated documentation
    files (the "Software"), to deal in the Software without
    restriction, including without limitation the rights to use,
    copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the
    Software is furnished to do so, subject to the following
    conditions:

    The above copyright notice and this permission notice shall be
    included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
    OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
    NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
    HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
    OTHER DEALINGS IN THE SOFTWARE.


    ════════════════════════════════════════════════════════════════════════

    Mermaid 11.16.0 — MIT License
    https://github.com/mermaid-js/mermaid

    The MIT License (MIT)

    Copyright (c) 2014 - 2022 Knut Sveidqvist

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.

    The Mermaid build bundled here carries its own attributions for the
    components compiled into it. Reproduced from that build:

      dompurify — DOMPurify 3.4.0 | (c) Cure53 and other contributors |
      Released under the Apache license 2.0 and Mozilla Public License 2.0 |
      github.com/cure53/DOMPurify/blob/3.4.0/LICENSE

      js-yaml — js-yaml 4.1.1, https://github.com/nodeca/js-yaml, MIT License

      lodash-es — Lodash (Custom Build), https://lodash.com/
      Copyright OpenJS Foundation and other contributors, https://openjsf.org/
      Released under MIT license, https://lodash.com/license
      Based on Underscore.js 1.8.3, http://underscorejs.org/LICENSE
      Copyright Jeremy Ashkenas, DocumentCloud and Investigative Reporters &
      Editors

      cytoscape — includes: Embeddable Minimum Strictly-Compliant Promises/A+
      1.1.1 Thenable, Copyright (c) 2013-2014 Ralf S. Engelschall
      (http://engelschall.com), MIT License; an event object based on jQuery
      events, MIT License, https://jquery.org/license/; a Bezier curve function
      generator, Copyright Gaetan Renaudeau, MIT License; and a Runge-Kutta
      spring physics function generator adapted from Framer.js, Copyright Koen
      Bok, MIT License.


    ════════════════════════════════════════════════════════════════════════

    KaTeX 0.16.47 — MIT License
    https://github.com/KaTeX/KaTeX

    Covers the KaTeX library, its stylesheet and the KaTeX web fonts bundled
    with this app.

    The MIT License (MIT)

    Copyright (c) 2013-2020 Khan Academy and other contributors

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.


    ════════════════════════════════════════════════════════════════════════

    highlight.js 11.11.1 — BSD 3-Clause License
    https://github.com/highlightjs/highlight.js

    BSD 3-Clause License

    Copyright (c) 2006, Ivan Sagalaev.
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice, this
      list of conditions and the following disclaimer.

    * Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.

    * Neither the name of the copyright holder nor the names of its
      contributors may be used to endorse or promote products derived from
      this software without specific prior written permission.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
    AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
    IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
    DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
    FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
    DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
    SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
    OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
    """#
}
