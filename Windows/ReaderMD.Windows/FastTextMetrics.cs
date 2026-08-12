using System.Numerics;
using System.Runtime.InteropServices;

namespace ReaderMD.Windows;

internal readonly record struct TextMetrics(int Words, int Characters);

internal static class FastTextMetrics
{
    public static TextMetrics Measure(string text)
    {
        return new TextMetrics(CountWords(text.AsSpan()), text.Length);
    }

    private static int CountWords(ReadOnlySpan<char> text)
    {
        if (text.IsEmpty)
        {
            return 0;
        }

        var values = MemoryMarshal.Cast<char, ushort>(text);
        var words = 0;
        var previousWhitespace = true;
        var index = 0;

        if (Vector.IsHardwareAccelerated && values.Length >= Vector<ushort>.Count)
        {
            var width = Vector<ushort>.Count;
            var space = new Vector<ushort>((ushort)' ');
            var tab = new Vector<ushort>((ushort)'\t');
            var lineFeed = new Vector<ushort>((ushort)'\n');
            var carriageReturn = new Vector<ushort>((ushort)'\r');

            for (; index <= values.Length - width; index += width)
            {
                var block = new Vector<ushort>(values.Slice(index, width));
                var commonWhitespace =
                    Vector.Equals(block, space) |
                    Vector.Equals(block, tab) |
                    Vector.Equals(block, lineFeed) |
                    Vector.Equals(block, carriageReturn);

                for (var lane = 0; lane < width; lane++)
                {
                    var value = values[index + lane];
                    var isWhitespace = commonWhitespace[lane] != 0 ||
                                       (value > 0x7F && char.IsWhiteSpace((char)value));
                    if (!isWhitespace && previousWhitespace)
                    {
                        words++;
                    }

                    previousWhitespace = isWhitespace;
                }
            }
        }

        for (; index < values.Length; index++)
        {
            var isWhitespace = char.IsWhiteSpace((char)values[index]);
            if (!isWhitespace && previousWhitespace)
            {
                words++;
            }

            previousWhitespace = isWhitespace;
        }

        return words;
    }
}
