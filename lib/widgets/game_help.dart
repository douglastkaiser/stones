import 'package:flutter/material.dart';

void showGameHelp(BuildContext context) {
  showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
            title: const Text('How to play Tak'),
            content: const SingleChildScrollView(
                child: Text(
                    'Build a road of your exposed flat stones and capstones connecting any two opposite edges. Diagonals do not connect.\n\n'
                    'Opening: each player places one opponent flat. Then place your own flat, wall, or capstone on an empty square. Walls block roads and cannot be covered except by a crushing capstone.\n\n'
                    'Place: tap an empty square, choose the piece type, then tap the selected square again to confirm. Cancel keeps the board unchanged.\n\n'
                    'Move: tap your stack to choose how many top pieces to carry (up to the board size). Move straight, dropping bottom pieces on every square. Tap or swipe along highlighted squares, then Confirm. A lone capstone can flatten a wall only on the final drop.\n\n'
                    'Inspect: hold a stack to see buried pieces. On a keyboard, use arrows to select a square and Enter to activate it; Escape cancels a preview. Use Undo in untimed offline games.\n\n'
                    'Scoring: a full board or exhausted reserve ends the game if no road wins. Only exposed flat stones score; capstones and walls do not. Equal flat counts draw.\n\n'
                    'Home keeps an offline match available during this session and pauses its clock. Refreshing the browser does not save it. Online games need a connection; their clocks keep running.')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'))
            ],
          ));
}
