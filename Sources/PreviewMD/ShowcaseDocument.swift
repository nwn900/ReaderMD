enum ShowcaseDocument {
    static let markdown = #"""
    # PreviewMD

    > [!TIP]
    > Drop any `.md` file into the window. PreviewMD renders everything locally, so your documents stay on your Mac.

    A focused Markdown reader built for **beautiful technical documents**. It combines a calm, print-inspired canvas with the power you expect from a serious developer tool.

    ## Project pulse

    | Area | Status | Owner | Progress |
    | :--- | :---: | :--- | ---: |
    | Native macOS shell | ✅ Ready | Design | 100% |
    | GFM renderer | ✅ Ready | Platform | 100% |
    | Mermaid diagrams | ✅ Ready | Data | 100% |
    | PDF export | 🟣 Polishing | Product | 92% |

    ## Workflow at a glance

    ```mermaid
    flowchart LR
        A[Open Markdown] --> B{Choose a view}
        B -->|Preview| C[Read beautifully]
        B -->|Split| D[Edit live]
        B -->|Source| E[Focus on text]
        C --> F[Export PDF]
        D --> F
        E --> D
    ```

    ## Built for real documentation

    - [x] GitHub Flavored Markdown tables and task lists
    - [x] Syntax highlighting with one-click copy
    - [x] Flowcharts, sequence diagrams, ER models, Gantt charts, and more
    - [x] Inline math like $E = mc^2$ and display equations
    - [x] Footnotes, local images, relative links, and automatic URLs
    - [ ] Your next excellent document

    ### Mathematics, typeset properly

    The Gaussian integral is rendered by KaTeX:

    $$
    \int_{-\infty}^{\infty} e^{-x^2}\,dx = \sqrt{\pi}
    $$

    ### Code that feels at home

    ```swift
    struct DocumentPreview: View {
        let markdown: String

        var body: some View {
            Reader(markdown)
                .readingWidth(.comfortable)
                .focusable()
        }
    }
    ```

    > [!NOTE]
    > Use the outline on the right to jump between sections. Press **⌘F** to search, **⌘O** to open files, and **⌘⇧E** to export a polished PDF.

    ## A sequence diagram

    ```mermaid
    sequenceDiagram
        participant You
        participant PreviewMD
        participant Renderer
        You->>PreviewMD: Open architecture.md
        PreviewMD->>Renderer: Parse GFM + diagrams + math
        Renderer-->>PreviewMD: Beautiful document
        PreviewMD-->>You: Read, search, export
    ```

    ## Small details, big difference

    Long tables scroll instead of breaking the page. Code blocks keep their language label. Links to local Markdown open as new tabs, while web links open in your browser. Your theme, reading width, paper mode, and recents persist between launches.[^privacy]

    [^privacy]: Rendering is offline. PreviewMD does not upload the contents of your documents.
    """#
}
