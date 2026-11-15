import 'package:flutter/material.dart';

const _shortcuts = {
  'Lists': [
    ('/', 'Search'),
    ('1–8', 'Pages in the visible bottom-bar order'),
    ('Home / End', 'Top / bottom of the loaded list'),
    ('Enter', 'Play or open'),
    ('F, hold Enter', 'Add to or remove from favorites'),
    ('Ctrl+↑ / Ctrl+↓', 'Move a favorite earlier / later'),
    ('G', 'Program guide'),
    ('R', 'Record / stop live TV (Linux)'),
    ('H', 'Hide'),
    ('Delete', 'Remove from history'),
    ('L', 'Local media (Linux)'),
    ('Esc, Backspace', 'Back'),
    ('Ctrl+= / Ctrl+-', 'Larger / smaller UI'),
    ('Ctrl+0', 'Normal UI size'),
    ('?', 'This list'),
  ],
  'mpv player': [
    ('PgUp / PgDn', 'Next / previous channel'),
    ('a / A', 'Next / previous feed'),
    ('i', 'Stream info, now and next'),
    ('r', 'Record / stop; confirm a connection conflict'),
    ('Backspace', 'Last channel'),
    ('F1–F9', 'Favorites 1–9 in Favorites order'),
    ('Digits, Enter', 'Channel number (if turned on)'),
  ],
  'Built-in player': [
    ('PgUp / PgDn', 'Next / previous channel'),
    ('Space', 'Play / pause'),
    ('R', 'Record / stop live TV (Linux)'),
    ('← / →', 'Back / forward 2 s'),
    ('J / I', 'Back / forward 10 s'),
    ('↑ / ↓', 'Volume'),
    ('F, Esc', 'Fullscreen, leave fullscreen'),
  ],
};

Future<void> showShortcuts(BuildContext context) => showDialog(
  context: context,
  builder: (context) => AlertDialog(
    // Title and list scroll together; Close stays on screen.
    scrollable: true,
    title: const Text('Keyboard shortcuts'),
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // One table, so the action column lines up across sections.
        Table(
          columnWidths: const {0: IntrinsicColumnWidth()},
          children: [
            for (final section in _shortcuts.entries) ...[
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Text(
                      section.key,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(),
                ],
              ),
              for (final (keys, action) in section.value)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 2, 16, 2),
                      child: Text(
                        keys,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(action),
                    ),
                  ],
                ),
            ],
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            'Settings → Keyboard shortcuts turns off /, 1–8, Home/End, G, H, L, Ctrl+↑/↓ and ?.',
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  ),
);
