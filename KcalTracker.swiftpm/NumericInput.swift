import SwiftUI
import UIKit

enum DecimalInput {
    static func parse(_ text: String) -> Double? {
        let separator = Locale.current.decimalSeparator ?? "."
        return Double(text.replacingOccurrences(of: separator, with: "."))
    }

    static func format(_ value: Double, maximumFractionDigits: Int = 10) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.groupingSeparator = ""
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func sanitize(_ input: String) -> String {
        let separator = Locale.current.decimalSeparator ?? "."
        let separatorCharacter = separator.first ?? "."
        var result = ""
        var hasDecimalSeparator = false

        for character in input {
            if let digit = character.wholeNumberValue, (0...9).contains(digit) {
                result.append(contentsOf: String(digit))
            } else if character == separatorCharacter && !hasDecimalSeparator {
                result.append(contentsOf: separator)
                hasDecimalSeparator = true
            }
        }

        return result
    }

    static func binding(_ source: Binding<String>) -> Binding<String> {
        Binding(
            get: { source.wrappedValue },
            set: { source.wrappedValue = sanitize($0) }
        )
    }
}

private enum IntegerInput {
    static func sanitize(_ input: String) -> String {
        input.reduce(into: "") { result, character in
            if let digit = character.wholeNumberValue, (0...9).contains(digit) {
                result.append(contentsOf: String(digit))
            }
        }
    }
}

private enum DecimalKeypadAction {
    case insert(String)
    case backspace
    case clear
    case next
    case done
}

private final class DecimalKeypadView: UIInputView {
    let decimalSeparator: String
    let showsDecimalSeparator: Bool
    let showsNext: Bool
    var onAction: ((DecimalKeypadAction) -> Void)?

    init(decimalSeparator: String, showsDecimalSeparator: Bool, showsNext: Bool) {
        self.decimalSeparator = decimalSeparator
        self.showsDecimalSeparator = showsDecimalSeparator
        self.showsNext = showsNext
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 310), inputViewStyle: .keyboard)
        allowsSelfSizing = true
        backgroundColor = .systemGroupedBackground
        buildLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 310)
    }

    private func buildLayout() {
        let content = UIStackView()
        content.axis = .vertical
        content.spacing = 8
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)

        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            content.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -8),
            content.centerXAnchor.constraint(equalTo: centerXAnchor),
            content.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),
            content.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
            content.widthAnchor.constraint(lessThanOrEqualToConstant: 480)
        ])

        let preferredWidth = content.widthAnchor.constraint(equalTo: widthAnchor, constant: -16)
        preferredWidth.priority = .defaultHigh
        preferredWidth.isActive = true

        let rows: [[String?]] = [
            ["1", "2", "3"],
            ["4", "5", "6"],
            ["7", "8", "9"],
            [showsDecimalSeparator ? decimalSeparator : nil, "0", "backspace"]
        ]

        for rowValues in rows {
            let row = UIStackView()
            row.axis = .horizontal
            row.distribution = .fillEqually
            row.spacing = 8

            for value in rowValues {
                if let value {
                    row.addArrangedSubview(makeKeyButton(value))
                } else {
                    let spacer = UIView()
                    spacer.backgroundColor = .clear
                    row.addArrangedSubview(spacer)
                }
            }

            content.addArrangedSubview(row)
            row.heightAnchor.constraint(equalToConstant: 48).isActive = true
        }

        content.addArrangedSubview(makeActionBar())
    }

    private func makeActionBar() -> UIView {
        let bar = UIStackView()
        bar.axis = .horizontal
        bar.spacing = 8

        bar.addArrangedSubview(
            makeActionButton(
                title: "Clear",
                action: .clear,
                emphasized: false,
                destructive: true
            )
        )
        bar.addArrangedSubview(UIView())

        bar.addArrangedSubview(
            makeActionButton(title: "Done", action: .done, emphasized: !showsNext)
        )
        if showsNext {
            bar.addArrangedSubview(
                makeActionButton(title: "Next", action: .next, emphasized: true)
            )
        }
        bar.heightAnchor.constraint(equalToConstant: 38).isActive = true
        return bar
    }

    private func makeActionButton(
        title: String,
        action: DecimalKeypadAction,
        emphasized: Bool,
        destructive: Bool = false
    ) -> UIButton {
        let button = UIButton(type: .system)
        var configuration = emphasized
            ? UIButton.Configuration.filled()
            : UIButton.Configuration.tinted()
        configuration.title = title
        configuration.cornerStyle = .medium
        if destructive {
            configuration.baseForegroundColor = .systemRed
            configuration.baseBackgroundColor = UIColor.systemRed.withAlphaComponent(0.14)
        }
        button.configuration = configuration
        button.addAction(UIAction { [weak self] _ in
            self?.onAction?(action)
        }, for: .touchUpInside)
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 76).isActive = true
        return button
    }

    private func makeKeyButton(_ value: String) -> UIButton {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.filled()
        configuration.baseBackgroundColor = .secondarySystemGroupedBackground
        configuration.baseForegroundColor = .label
        configuration.cornerStyle = .medium

        if value == "backspace" {
            configuration.image = UIImage(systemName: "delete.left")
            button.accessibilityLabel = "Delete"
        } else {
            configuration.title = value
            button.accessibilityLabel = value == decimalSeparator ? "Decimal separator" : value
        }

        button.configuration = configuration
        button.titleLabel?.font = .preferredFont(forTextStyle: .title2)
        button.addAction(UIAction { [weak self] _ in
            self?.onAction?(value == "backspace" ? .backspace : .insert(value))
        }, for: .touchUpInside)
        return button
    }
}

struct DecimalKeypadTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String

    let focus: Binding<Bool>
    let showsDecimalSeparator: Bool
    let showsNext: Bool
    let isBordered: Bool
    let textAlignment: NSTextAlignment
    let textStyle: UIFont.TextStyle
    let onNext: () -> Void
    let onDone: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    init(
        _ placeholder: String,
        text: Binding<String>,
        focus: Binding<Bool> = .constant(false),
        showsDecimalSeparator: Bool = true,
        showsNext: Bool = false,
        isBordered: Bool = false,
        textAlignment: NSTextAlignment = .natural,
        textStyle: UIFont.TextStyle = .body,
        onNext: @escaping () -> Void = {},
        onDone: @escaping () -> Void = {}
    ) {
        self.placeholder = placeholder
        self._text = text
        self.focus = focus
        self.showsDecimalSeparator = showsDecimalSeparator
        self.showsNext = showsNext
        self.isBordered = isBordered
        self.textAlignment = textAlignment
        self.textStyle = textStyle
        self.onNext = onNext
        self.onDone = onDone
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.font = .preferredFont(forTextStyle: textStyle)
        textField.adjustsFontForContentSizeCategory = true
        textField.clearButtonMode = .never
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingChanged(_:)),
            for: .editingChanged
        )
        context.coordinator.configureKeyboard(for: textField)
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        context.coordinator.parent = self
        context.coordinator.configureKeyboard(for: textField)

        if textField.text != text {
            textField.text = text
        }
        textField.placeholder = placeholder
        textField.textAlignment = textAlignment
        textField.font = .preferredFont(forTextStyle: textStyle)
        textField.borderStyle = isBordered ? .roundedRect : .none
        textField.isEnabled = isEnabled

        if focus.wrappedValue, !textField.isFirstResponder {
            DispatchQueue.main.async {
                guard self.focus.wrappedValue else { return }
                textField.becomeFirstResponder()
            }
        } else if !focus.wrappedValue, textField.isFirstResponder {
            DispatchQueue.main.async {
                guard !self.focus.wrappedValue else { return }
                textField.resignFirstResponder()
            }
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: DecimalKeypadTextField
        private var keypad: DecimalKeypadView?

        init(_ parent: DecimalKeypadTextField) {
            self.parent = parent
        }

        func configureKeyboard(for textField: UITextField) {
            let separator = Locale.current.decimalSeparator ?? "."
            if keypad?.decimalSeparator == separator,
               keypad?.showsDecimalSeparator == parent.showsDecimalSeparator,
               keypad?.showsNext == parent.showsNext {
                return
            }

            let keypad = DecimalKeypadView(
                decimalSeparator: separator,
                showsDecimalSeparator: parent.showsDecimalSeparator,
                showsNext: parent.showsNext
            )
            keypad.onAction = { [weak self, weak textField] action in
                guard let self, let textField else { return }
                self.handle(action, in: textField)
            }
            self.keypad = keypad
            textField.inputView = keypad
            if textField.isFirstResponder {
                textField.reloadInputViews()
            }
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            if !parent.focus.wrappedValue {
                parent.focus.wrappedValue = true
            }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if parent.focus.wrappedValue {
                parent.focus.wrappedValue = false
            }
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            let current = textField.text ?? ""
            guard let swiftRange = Range(range, in: current) else { return false }
            let candidate = current.replacingCharacters(in: swiftRange, with: string)
            return sanitized(candidate) == candidate
        }

        @objc func editingChanged(_ textField: UITextField) {
            sync(textField)
        }

        private func handle(_ action: DecimalKeypadAction, in textField: UITextField) {
            switch action {
            case .insert(let value):
                replaceSelection(in: textField, with: value)
            case .backspace:
                deleteSelection(in: textField)
            case .clear:
                apply("", cursorOffset: 0, to: textField)
            case .next:
                sync(textField)
                parent.onNext()
            case .done:
                sync(textField)
                parent.focus.wrappedValue = false
                textField.resignFirstResponder()
                parent.onDone()
            }
        }

        private func replaceSelection(in textField: UITextField, with replacement: String) {
            let current = textField.text ?? ""
            let selection = selectedRange(in: textField)
            let candidate = (current as NSString).replacingCharacters(in: selection, with: replacement)
            guard sanitized(candidate) == candidate else { return }
            apply(candidate, cursorOffset: selection.location + replacement.utf16.count, to: textField)
        }

        private func deleteSelection(in textField: UITextField) {
            let current = textField.text ?? ""
            var selection = selectedRange(in: textField)
            guard selection.location > 0 || selection.length > 0 else { return }
            if selection.length == 0 {
                selection.location -= 1
                selection.length = 1
            }
            let candidate = (current as NSString).replacingCharacters(in: selection, with: "")
            apply(candidate, cursorOffset: selection.location, to: textField)
        }

        private func apply(_ value: String, cursorOffset: Int, to textField: UITextField) {
            textField.text = value
            if let position = textField.position(
                from: textField.beginningOfDocument,
                offset: min(cursorOffset, value.utf16.count)
            ) {
                textField.selectedTextRange = textField.textRange(from: position, to: position)
            }
            sync(textField)
        }

        private func selectedRange(in textField: UITextField) -> NSRange {
            guard let selectedRange = textField.selectedTextRange else {
                return NSRange(location: (textField.text ?? "").utf16.count, length: 0)
            }
            let location = textField.offset(
                from: textField.beginningOfDocument,
                to: selectedRange.start
            )
            let length = textField.offset(from: selectedRange.start, to: selectedRange.end)
            return NSRange(location: location, length: length)
        }

        private func sanitized(_ input: String) -> String {
            parent.showsDecimalSeparator
                ? DecimalInput.sanitize(input)
                : IntegerInput.sanitize(input)
        }

        private func sync(_ textField: UITextField) {
            let value = sanitized(textField.text ?? "")
            if textField.text != value {
                textField.text = value
            }
            if parent.text != value {
                parent.text = value
            }
        }
    }
}

struct DecimalValueTextField: View {
    let prompt: String
    @Binding var value: Double?

    private let maximumFractionDigits: Int
    @State private var text: String
    @State private var isFocused = false

    init(
        _ prompt: String,
        value: Binding<Double?>,
        maximumFractionDigits: Int = 1
    ) {
        self.prompt = prompt
        self._value = value
        self.maximumFractionDigits = maximumFractionDigits
        self._text = State(
            initialValue: value.wrappedValue.map {
                DecimalInput.format($0, maximumFractionDigits: maximumFractionDigits)
            } ?? ""
        )
    }

    var body: some View {
        DecimalKeypadTextField(
            prompt,
            text: $text,
            focus: focusBinding,
            textAlignment: .right,
            onDone: {
                isFocused = false
            }
        )
            .onChange(of: text) { _, newValue in
                value = DecimalInput.parse(newValue)
            }
            .onChange(of: value) { _, newValue in
                guard !isFocused else { return }
                text = newValue.map {
                    DecimalInput.format($0, maximumFractionDigits: maximumFractionDigits)
                } ?? ""
            }
            .onChange(of: isFocused) { _, nowFocused in
                guard !nowFocused else { return }
                text = value.map {
                    DecimalInput.format($0, maximumFractionDigits: maximumFractionDigits)
                } ?? ""
            }
    }

    private var focusBinding: Binding<Bool> {
        Binding(
            get: { isFocused },
            set: { isFocused = $0 }
        )
    }
}

struct IntegerValueTextField: View {
    let prompt: String
    @Binding var value: Int?

    @State private var text: String
    @State private var isFocused = false

    init(_ prompt: String, value: Binding<Int?>) {
        self.prompt = prompt
        self._value = value
        self._text = State(initialValue: value.wrappedValue.map(String.init) ?? "")
    }

    var body: some View {
        DecimalKeypadTextField(
            prompt,
            text: $text,
            focus: focusBinding,
            showsDecimalSeparator: false,
            textAlignment: .right,
            onDone: {
                isFocused = false
            }
        )
        .onChange(of: text) { _, newValue in
            value = Int(newValue)
        }
        .onChange(of: value) { _, newValue in
            guard !isFocused else { return }
            text = newValue.map(String.init) ?? ""
        }
        .onChange(of: isFocused) { _, nowFocused in
            guard !nowFocused else { return }
            text = value.map(String.init) ?? ""
        }
    }

    private var focusBinding: Binding<Bool> {
        Binding(
            get: { isFocused },
            set: { isFocused = $0 }
        )
    }
}
