// apps/calculator/lib/calculator_app.dart
import 'package:flutter/material.dart';
import 'package:psito_sdk/psito_sdk.dart';

import 'l10n/calculator_localizations.dart';

class CalculatorView extends StatefulWidget {
  const CalculatorView({super.key});

  @override
  State<CalculatorView> createState() => _CalculatorViewState();
}

class _CalculatorViewState extends State<CalculatorView> {
  String _output = '0';
  String _currentOperand = '';
  double _num1 = 0;
  double _num2 = 0;
  String _operator = '';

  void _buttonPressed(String buttonText) {
    setState(() {
      if (buttonText == 'C') {
        _output = '0';
        _currentOperand = '';
        _num1 = 0;
        _num2 = 0;
        _operator = '';
      } else if (buttonText == '+' ||
          buttonText == '-' ||
          buttonText == '×' ||
          buttonText == '÷') {
        _num1 = double.tryParse(_output) ?? 0;
        _operator = buttonText;
        _currentOperand = '';
      } else if (buttonText == '=') {
        _num2 = double.tryParse(_output) ?? 0;
        if (_operator == '+') {
          _output = (_num1 + _num2).toString();
        } else if (_operator == '-') {
          _output = (_num1 - _num2).toString();
        } else if (_operator == '×') {
          _output = (_num1 * _num2).toString();
        } else if (_operator == '÷') {
          _output = _num2 != 0
              ? (_num1 / _num2).toString()
              : CalculatorLocalizations.of(context).error;
        }
        // Remove .0 se for inteiro para ficar limpo
        if (_output.endsWith('.0')) {
          _output = _output.substring(0, _output.length - 2);
        }
        _operator = '';
        _currentOperand = '';
      } else {
        if (_currentOperand == '0' && buttonText != '.') {
          _currentOperand = buttonText;
        } else {
          _currentOperand += buttonText;
        }
        _output = _currentOperand;
      }
    });
  }

  Widget _buildButton(String text, {Color? color, Color? textColor}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Material(
          color: color ?? const Color(0xFF263238),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () => _buttonPressed(text),
            borderRadius: BorderRadius.circular(10),
            child: Center(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor ?? Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Visor da Calculadora
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          alignment: Alignment.bottomRight,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Text(
            _output,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFFC107), // Amarelo Calopsita
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Teclado da Calculadora
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      _buildButton(
                        'C',
                        color: Colors.red.withValues(alpha: 0.3),
                        textColor: Colors.redAccent,
                      ),
                      _buildButton('÷', color: const Color(0xFF37474F)),
                      _buildButton('×', color: const Color(0xFF37474F)),
                      _buildButton('-', color: const Color(0xFF37474F)),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildButton('7'),
                      _buildButton('8'),
                      _buildButton('9'),
                      _buildButton('+', color: const Color(0xFF37474F)),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildButton('4'),
                      _buildButton('5'),
                      _buildButton('6'),
                      _buildButton(
                        '=',
                        color: const Color(0xFFFFC107),
                        textColor: Colors.black,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildButton('1'),
                      _buildButton('2'),
                      _buildButton('3'),
                      _buildButton('0'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class CalculatorApp extends PsitoApp {
  const CalculatorApp();

  @override
  String get id => 'calculator';

  @override
  String get name => 'Calculator';

  @override
  String localizedName(Locale locale) =>
      lookupCalculatorLocalizations(locale).appName;

  @override
  List<LocalizationsDelegate<dynamic>> get localizationsDelegates => const [
    CalculatorLocalizations.delegate,
  ];

  @override
  IconData get icon => Icons.calculate_outlined;

  @override
  Color get color => const Color(0xFF2196F3);

  @override
  Widget build(PsitoAppContext context) => const CalculatorView();
}
