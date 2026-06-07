pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // Бронебойный парсер: если цвет пустой или невалидный, принудительно отдаем рабочий объект цвета #1a1a1a
    function getValidColor(targetColor) {
        if (!targetColor || targetColor === "" || targetColor === "transparent") {
            return Qt.color("#1a1a1a");
        }
        var parsed = Qt.color(targetColor);
        if (isNaN(parsed.r)) {
            return Qt.color("#1a1a1a");
        }
        return parsed;
    }

    function colorWithHueOf(color1, color2) {
        var c1 = getValidColor(color1);
        var c2 = getValidColor(color2);
        var hue = c2.hsvHue;
        var sat = c1.hsvSaturation;
        var val = c1.hsvValue;
        var alpha = c1.a;
        return Qt.hsva(hue, sat, val, alpha);
    }

    function colorWithSaturationOf(color1, color2) {
        var c1 = getValidColor(color1);
        var c2 = getValidColor(color2);
        var hue = c1.hsvHue;
        var sat = c2.hsvSaturation;
        var val = c1.hsvValue;
        var alpha = c1.a;
        return Qt.hsva(hue, sat, val, alpha);
    }

    // Фикс для NaN во входящих параметрах яркости
    function colorWithLightness(color, lightness) {
        var c = getValidColor(color);
        var safeLightness = (lightness !== undefined && !isNaN(lightness)) ? lightness : 0.5;
        return Qt.hsla(c.hslHue, c.hslSaturation, safeLightness, c.a);
    }

    // Безопасный вызов дочерней функции
    function colorWithLightnessOf(color1, color2) {
        var c2 = getValidColor(color2);
        return colorWithLightness(color1, c2.hslLightness);
    }

    function adaptToAccent(color1, color2) {
        var c1 = getValidColor(color1);
        var c2 = getValidColor(color2);
        var hue = c2.hslHue;
        var sat = c2.hslSaturation;
        var light = c1.hslLightness;
        var alpha = c1.a;
        return Qt.hsla(hue, sat, light, alpha);
    }

    function mix(color1, color2, percentage = 0.5) {
        var c1 = getValidColor(color1);
        var c2 = getValidColor(color2);
        var p = (percentage !== undefined && !isNaN(percentage)) ? percentage : 0.5;
        return Qt.rgba(
            p * c1.r + (1 - p) * c2.r,
            p * c1.g + (1 - p) * c2.g,
            p * c1.b + (1 - p) * c2.b,
            p * c1.a + (1 - p) * c2.a
        );
    }

    // Защита от неопределенного процента прозрачности
    function transparentize(color, percentage = 1) {
        var c = getValidColor(color);
        var p = (percentage !== undefined && !isNaN(percentage)) ? percentage : 1;
        return Qt.rgba(c.r, c.g, c.b, c.a * (1 - p));
    }

    function applyAlpha(color, alpha) {
        var c = getValidColor(color);
        var a = (alpha !== undefined && !isNaN(alpha)) ? Math.max(0, Math.min(1, alpha)) : 1;
        return Qt.rgba(c.r, c.g, c.b, a);
    }
}
