import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Komponen universal untuk merender gambar konser dari berbagai sumber:
/// 1. Data URL Base64 (`data:image/png;base64,...` atau `data:image/jpeg;base64,...`)
/// 2. Raw Uint8List bytes
/// 3. Network URL (`http://...` atau `https://...`)
/// 4. Asset lokal (`assets/...`)
/// 5. Fallback ke placeholder/ikon dengan gradien yang elegan jika tidak ada gambar
class ConcertImageWidget extends StatelessWidget {
  final String? imageSource;
  final Uint8List? imageBytes;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? fallbackWidget;
  final IconData fallbackIcon;
  final String? fallbackLabel;

  const ConcertImageWidget({
    super.key,
    this.imageSource,
    this.imageBytes,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.fallbackWidget,
    this.fallbackIcon = Icons.image_outlined,
    this.fallbackLabel,
  });

  /// Koleksi karya visual poster & logo bawaan LiveTix (format data:image PNG base64)
  /// agar konser dummy langsung menampilkan visual konser yang nyata dan tidak kosong.
  static const String sampleSoundwavePng =
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAFKElEQVR4nOXbB2+WZRQG4Odn8O09qlGjRo0jWjq/PUBEwLZ00E33opvOr4VSoIyW0tLd0j1QcEaNGkfUqFHjiBo1+jNu85zkJP6H8xOuu1/f93nPcx+VeeQespIHyE4eICe5j0ByH8HkPkLJPUSSe4gmdhFL7CKR2EUysYMjiR0cTezgWGIbr8S3cTy+hRPxLZyMb+FUfBN58U3kxzdQENtAYWwDRbF1FMfWURJbR2nsLspid1EeXUNldA1V0TVUR1dRE11FbXQFddEV1EdW0BhZRlNkGc2RZbRGltAWWcK5yCI6wovoDC+iK7yAnvACesMLOB+eR194HgOhOQyG5jAUmkMqdAcjoTsYDc3iYmgWY8FZXArOYDw4gyvBGVwN3sZE8DauB6ehJONv6AAYb08bhSNtFM60EbjTRuDxp+D1p+D3p5DmH8ZD/mE87B/GI/4hPOobwmO+QTzuG8QTvkE86RvAU74BPO3rxzPefjzr7cdz3j487+3DC94+vOg9j5e855Hu6UWGpxeZnl5keXqQ4+lBrqcbAU83gu5uhN1diLi7EHV3Ie7uRMLdiaS7A0ddHXjZ1YFjrnYcd7XjVVc7TrjO4aTrHF5ztiHP2YZ8ZxtOO1tR6GxFkbMFJc4WnHG0oNTRjDJHMyoczah0NKHK0YSzjkbC3wxMQ/FfXhK+xtFI+KnALSj+2UvC19obCX9LB8D/85Lw9fYGwk8HpqD4gScJ32BvIPyMDoCf9pLwjfZ6ws/qAPhVJwnfbK8n/J3AJBS/5yXhW+z1hJ/LnYTiQ44kfKu9jvALOgA+4UnCt9nqCL+YexOKj7eS8O22OsIv6QD4bC8J32GrJfxK7g0o/rCRhO+01RJ+VQfAX3WS8N22GsKv6QD4k1YSvsdWQ/j1nOtQ/D0vCd9rqyH8hg6AhxmS8H3Ws4TfzLkGxZMcSfh+61nCb+kAeIwlCT9grSb8jg6AZ3iS8IPWasLv5kxA8QBTEn7YWk34PR0AT28l4VPWKsIfZE9A8ehaEn7EWkX4e9lXoXhuLwl/wVJF+Nd1AHxpIQl/0VJJ+PvZV6D4xkYSfsxSSfgHOgC+rpKEH7dUEP5NHQDf1UnCX7ZUEP7t7MtQfFEpCX/FUkH4d7IuQ/EtrST8hKWc8O/qAPiKWhL+mrmc8O9ljUPx/bwk/HVzOeHf1wFwOUES/oa5jPAfZF2C4maGJPykuYzwH+oAuJYiCT9lLiX8RzoA7uRIwt8ylxL+48wxKC4kScLfNpcS/hMdALexJOFnTGcI/2nmRSiuoknCz5rOEP4zHQD38CTh50wlhP9cB8AlREn4eVMJ4b/IvADFDUxJ+AVTCeG/1AFw/VQSftFUTPivMi5AcfdWEn7ZVEz4rzNGobh4LAm/Yiwm/Dc6AG5dS8KvGosI/23GCBRXziXh7xqLCP+dDoD79pLw68ZCwn+vA+BlA0n4DWMh4X/ISEHxpoUk/JaxkPA/Hk5B8ZqJJPy28TThfzo8DMU7NpLwO4bThP9ZB8ALRpLwe4YCwv+iA+DtKkn4fUMB4X89PATFq2WS8AeGAsL/pgPgvTpJ+HuGfML/rgPgpUJJ+DcM+YT/I30QijcqJeHvG/IJ/6cOgNdJJeEfHMoj/F/pA1C8SysJ/9ahPML/rQP4/yIxr5PyUiGvlvGCEa+Z8LIBV865eMz1Uy4hchWNC0lcS+FyAl9R80UlX1fxpQWPrnmAyWMsHmbwJy1/2PDxlg85/KrjBx7/7Bn/jw5AMv7f9H78B3sx5gMBn6kiAAAAAElFTkSuQmCC';

  static const String sampleSymphonyPng =
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAFPElEQVR4nOXb91ZUVxQG8PMKSYwzd8qdSUyMibEXBJHbC4JI770qoogiiiKKKKKIYu81vffee88rfVl337XXyjvsP+YBfntm7j1n72+rAqMa0WeTUYNCoxaFRh2KjHpsNhpQbDSi2GjCFqMZJUYLSoxWGEYbTLMdltkBy+yEbXbBMbvhmD1wzV54Zh98sx++OYDA3IHQ3InQHESptQtbrSGUWbtRZu1BuTWMbdZeVFgjqLD2Ybu1H5XWKCqtA6iyxlBtHUSNfQg19jhq7cOos4+gzp5AvX0UDfYkGu1jaLSPo8meQrN9As32NFrsk2h1TqHNmUGbcxrtziw6nDPocM6i05lDl3MO3c48up3z6HEuoNdZgJKM73MvQjH+scQKPJ5YiScSq7AosRqLEmvwZGItFifWYXFiPRKJDUgmN0JLFkBLbkIqWYh0sgjp5GZkksXIJrdAT5ZATxrIJU3kkxbySRtPaQ6e1lws0Tws0Xw8owV4VguxVCvFUm0rntPKsEwrxzJtG57XKvCCth3LU5VYnqrCi6lqrEjVYEWqFitTdViVqsfqVANWpxqxJtWEtalmrE21YF2qFevTbdiQbseGdAc2pjtRkO5CQbobm9I9KEz3oijdh6J0PzanB1Cc3kF4KgB/85LwWzI7Cd/vXooKEP/sJeGjT4QfcC9D8X9eEr4kM0j4AfcKFD/wJOGNzC7C73CvQvHTXhLeyAwRfqd7LSpA/KqThDczuwk/6F6H4ve8JLyV2UP4QfcGFB9yJOHtzDDhd7k3owLEJzxJeDuzl/BD7i0oPt5KwjuZEcIPubeh+GwvCe9m9hF+t3sHii82kvBuZj/h93h3owLEtzpJeC8zSvhh7x4UX2kl4f3sAcIPe/eh+D4vCR9kxwi/13sQFSBuZkjCB9mDhB/xHkJxJ0cSPsweIvyI9wiK21iS8KXZccLv816C4h6eJHxp9jDh93svRwWIG5iS8FuzRwg/6r0Cxd1bSfiy7AThR71Xobh1LQlfnj1K+APea1EB4r69JHx5dpLwY97rUDy0kITflj1G+DHvDSie2EjCV2SPE/6g/yYUj6sk4SuyU4Q/5L8VFSCe1UnCb9dPEH7cfxuKB5WS8JX6NOHH/XegeEorCV+lnyT8Yf9dKB5RS8JX6acIf8R/LypAPJ+XhK/WZwg/4b8PxeEESfga/TThJ/wPoDiZIQlfq88S/qj/YVSAOJYiCV+rnyH8pP8RFGdyJOHr9LOEn/Q/huJAkiR8vT5H+GP+J1CcxpKEr9fPEf64/2lUgDiKJgnfoM8Tfir4DIpzeJLwjfp5wk8Fn0NxCFESvil3gfAngi+iAsQJTEn4ptwC4aeDL6E4fioJ35y7SPjp4Csozt5KwrfkLhH+ZPA1FAePJeFbcpcJfyr4JipAnLqWhG/NXSH8TPAtFEfOJeHbclcJPxN8B8V5e0n49tw1wp8Ovo8KEC8bSMK3564Tfjb4AYo3LSThO3I3CD8b/AjFayaS8J25m4Q/E/wExTs2kvCduVuEPxv+HBUgXjCShO/K3Sb8XPgLFG9XScJ35+8Qfi78FYpXyyThe/J3CX8u/C0qQLxXJwnfk79H+PnwdyheKpSE783fJ/x8+AcUb1RKwvflHxD+fPgnFK+TSsL35R8S/kL4V1SAeJdWEr4//4jwC+HfUP9fJOZ1Ul4q5NUyXjDiNRNeNuDIOQePOX7KIUSOonEgiWMpHE7gETUPKnlcxUMLbl1zA5PbWNzM4CstX2z4eMuHHH7V8QOPf/aMXwj/gZKMvxj+i/8A5fTGJWB+G4AAAAAASUVORK5CYII=';

  static const String sampleRockAnthemPng =
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAFLklEQVR4nOXbY5dcWRQG4PM9ZVf1l7EzaneXK7Y5sW07mdge2zbCjm07bTPmO+vsdfda8x/2T3jerr733H3erXIbNEBuwwRyGyWQ1ziBvCYJ5DdNIL9ZAgXNEyhoEUdhyzgKW8VR1DqOojZxFLeNo7hdHCXt4yjpEENJxxhKO8VQ2jmGsi4xlHWNobxbDOXdo6h4K4qKHlFU9oyislcUVb2jqOoTRXXfKKr7RVDTP4KaARHUDIygdlAEtYMjqBsSQd3QMG4MC+PG8DBujgjj5sgwbo0K49boMG6PCeP22BDujAvhzvgQ7kwI4e7EEO5OCuHe5BDuTQni/tQg7k8L4sH0IB7MCOLhzCAezgri0ewgHs3JxuO52Xg8LxtKMh7zdQAGftMTSdj8ZBI2P5WELU8nYcszAWx9NoCtzwWw7fkAtr0QwPYXA9j+UgA5LweQ84ofOfX92PGqHzte82Pn637sfMOPXW/6sSvZh90pPuxO9WFPmg970n3Ym+HD3kwf9mX5sC/bi/1BL/aHvNgf9uJAxIsDUS8Oxrw4GPfgUMKDQw08ONzQg8ONPDjS2IMjTTw42tSDo83cONbcjWMt3DjW0o3jrdw43tqNE23cONHWhZPtXDjZ3oVTHVw41dGF051cON3ZhTNdXDjT1Ymz3Zw4291JeCzIhuK/vCT8uR5OwmOhDsD42UvCn+vpJDwWZUPx/7wk/LleTsJjcRYUP/Ak4c/3dhIeS7Kg+GkvCX++j4PwWKoDMF51kvAX+joIj2VZUPyel4S/0M9BeCzXARiHHEn4i/0dhMeKLCg+4UnCXxzgIDxW6gCM460k/KWBDsJjVRYUn+0l4S8NchAeqzOh+MNGEv7yYAfhsSYTir/qJOEvD7ETHmt1AMYnrST8laF2wmOdDsD4npeEvzLMTnisz4TiYYYk/NXhdsJjgw7AmORIwl8dYSc8NmZC8RhLEv7qSDvh8U4GFM/wJOGvjbITHu9mQPEAUxL+2mgb4fGeDsCY3krCXx9jIzzez4Di0bUk/PWxNsLjAx2AMbeXhM8dZyM8PsyA4ksLSfjc8TbC4yMdgHFjIwmfN8FGeHycAcXXVZLweRNthMcn6VB8VycJnz/JRnh8mg7FF5WS8PmTrYTHZzoA45ZWEr5gipXw+Dwdiq+oJeELploJjy90AMb9vCR84TQr4fGlDsAoJ0jCF063Eh5fpUNxM0MSvmiGlfD4Og2KaymS8EUzrYTHN2lQ3MmRhC+aZSE8vtUBGIUkSfji2RbC47s0KG5jScIXz7EQHt/rAIwqmiR8yVwL4fFDGhT38CThS+ZZCI8fdQBGCVESvvRtC+HxUxoUNzAl4UvnWwiPn1OhuH4qCV+2wEJ4/JIKxd1bSfiyhWbC41cdgFE8loQvX2QmPH5LheLWtSR8+WIz4fG7DsConEvCVywxEx5/6ACMvr0kfMVSM+HxZyoULxtIwlcuMxMef6VA8aaFJHzlcjPh8XcKFK+ZSMJXrjARHv/oAIwdG0n4qpUmwuPfFCheMJKEr1plIjw26QCM7SpJ+OrVJsJjcwoUr5ZJwlevMREeW3QAxl6dJHzNWhPhsTUFipcKJeFr1pkIj23JULxRKQlfu95EeGxPhuJ1Ukn42g31CI8cHYCxSysJX7exHuGxIxnq/4vEvE7KS4W8WsYLRrxmwssGXDnn4jHXT7mEyFU0LiRxLYXLCXxFzReVfF3FlxY8uuYBJo+xeJjBn7T8YcPHWz7k8KuOH3j8s2c8duoABOOxKxn/AVetGETRt96TAAAAAElFTkSuQmCC';

  static const String sampleFestivalGajayanaPng =
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAFGUlEQVR4nOXb51pUVxQG4P1r2plyJ9POlF/GqDFGE2MBERSxgUPvZWCGXqQKShNEUWliwUKaSUwxzRSTmGKaSS7ly7PXOet5cg/rx7qA92OY2XvttVSw+TSoWooRTBcj2FqCYFsJgpkzVmVTCLanEOwoRbCzDMGuMoS6yhHqLkeopwKh3gqE+ioR6tdVhdBAFUJnqxEarEFoqAah4Vqq8EgdwqN1CI/VI3yuHuHxBqsmGhE+34TwhSaEJ5sRntLVgvB0CyIzaURm04hcbEVkTlcbIvMZRC5lEFnIInI5i8iVdqsWOxC52oHotU5Er3ciutSF6FI3osvdiK70ILrag+haL6I3dPUhut6H6M1+KMl489YAFOMdB7bAcXALHDkvWZW7FY5DW+HIexmOw9vgyN8GZ/52OAu2w3lkB5xHd8BZ+Aqcx3TthLNoJ5zHX4XzxC44T+6C89RrVK7Tu+Eq3g1XyR64zuyBK/W6VaVvwFW2F67yvXBVvAlXpa59cFXtg7t6P9w1++GuPQB3na6DcNfnwN2QA3djLtxNuXA3H7KqJQ/udB48rYfhaTsMTyYfnkwBPNkCeNqPwNNxBJ7Oo/B06SqEp7sQnp5jhDdv6wDsv7wkvNFbRHjzzlko/thLwht9RYQ3N3QA9v+8JLzRf5zw5sYgFH/hScIbAzqAQZh3OYBsShTeGDhBePPeEBT/1EnCG2dPEN68rwOwf+cl4Y3Bk4Q3HwxD8SFHEt4YOkl4c1MHYJ/wJOGN4VOENzdHoPh4KwlvjOgARmC+NQrFZ3tJeGPkNOHNt3UA9sVGEt4YLSZ87J0xKL7VScIbY8WEj72rA7CvtJLw3nMlhI+9dw6K7/OS8N7xEsJbAdjNDEl478QZK4CH4zoAq5MjCU8BPBxH7H0dgN3GkoT3nk8RPvbBBBT38CThvRdShI99qAOwG5iS8N7JUsLHHp2H4u6tJLx3qpTwsUcXoLh1LQnvnS4jfOwjOwDdt5eE906XEz728SQUP1pIwntnygkf+0QHYL/YSMJ7ZysIH/90CoqfqyThvRcrCB9/rAOw3+ok4X1zlYSPP56G4odKSXjfvA5gGvHPOICJRlF433wV4eOfz0DxE7UkvO9SFeHjX+gA7Pd5SXjfQjXh41/OQvFwgiS873I14eNfXYTiyQxJeN+VGsJbAdhjKZLwvsVaK4AnczoAayZHEp4CeDKH+Nc6AHsgSRLed7WO8PFv5qF4GksS3netjvDxb3UA9iiaJLzvej3hE99dguI5PEl431I94a0A7CFESXj/coMVwNMFHYA1gSkJTwE8XUDiex2APX4qCe9faSR84ofLUDx7KwnvX20kfOLHK1A8eCwJ719rInzimQ7AnrqWhPffaCZ84tkiFI+cS8L713UAi0j8xAEsdojC+9dbCJ/4+SoULxtIwvtvthA+8YsOwN60kIT330oTPvHrNSheM5GE999OEz7xXAdg79hIwvvvtBI++fw6FC8YScL7N1oJn/yNArC2qyThAxtthE/+vgTFq2WS8IG7bYRP/rEMxXt1kvCBexnCJ//UAdhLhZLwgftZwif/WoHijUpJ+MCDLOGtAOx1Ukn4wGa7FcCLVR2AtUsrCU8BvFhF8m8dwP8WiXmdlJcKebWMF4x4zYSXDXjknAePefyUhxB5FI0HkngshYcT+ImaHyr5uYofLbh1zQ1MbmNxM4OvtHyx4eMtH3L4p46/8Phjz/jkP2tQkvHJf9fwH8UkczGohf3TAAAAAElFTkSuQmCC';

  static const Map<String, String> sampleArtworks = {
    'poster_soundwave.png': sampleSoundwavePng,
    'logo_soundwave_square.png': sampleSoundwavePng,
    'poster_symphony.png': sampleSymphonyPng,
    'logo_symphony_square.png': sampleSymphonyPng,
    'poster_rock_anthem.png': sampleRockAnthemPng,
    'logo_rock_anthem_square.png': sampleRockAnthemPng,
    'poster_harmoni_final.png': sampleFestivalGajayanaPng,
    'logo_harmoni_square.png': sampleFestivalGajayanaPng,
    'poster_konser.png': sampleSoundwavePng,
    'logo_1x1.png': sampleSoundwavePng,
  };

  bool get hasImage {
    if (imageBytes != null && imageBytes!.isNotEmpty) return true;
    final src = imageSource?.trim() ?? '';
    if (sampleArtworks.containsKey(src)) return true;
    return src.isNotEmpty &&
        (src.startsWith('data:image/') ||
            src.startsWith('http://') ||
            src.startsWith('https://') ||
            src.startsWith('assets/'));
  }

  Uint8List? _extractBytes() {
    if (imageBytes != null && imageBytes!.isNotEmpty) {
      return imageBytes;
    }
    var src = imageSource?.trim() ?? '';
    if (sampleArtworks.containsKey(src)) {
      src = sampleArtworks[src]!;
    }
    if (src.startsWith('data:image/')) {
      final commaIdx = src.indexOf(',');
      if (commaIdx != -1) {
        try {
          return base64Decode(src.substring(commaIdx + 1));
        } catch (_) {
          return null;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    final extractedBytes = _extractBytes();

    if (extractedBytes != null) {
      content = Image.memory(
        extractedBytes,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _buildFallback(),
      );
    } else {
      final src = imageSource?.trim() ?? '';
      if (src.startsWith('http://') || src.startsWith('https://')) {
        content = Image.network(
          src,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => _buildFallback(),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: width,
              height: height,
              color: const Color(0xFFF1F5F9),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
        );
      } else if (src.startsWith('assets/')) {
        content = Image.asset(
          src,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => _buildFallback(),
        );
      } else {
        content = _buildFallback();
      }
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: content,
      );
    }

    return content;
  }

  Widget _buildFallback() {
    if (fallbackWidget != null) return fallbackWidget!;

    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF1B2A8C), // Navy
            Color(0xFF6B1D7C),
            Color(0xFFC2185B), // Magenta
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(fallbackIcon, size: 28, color: Colors.white70),
            if (fallbackLabel != null && fallbackLabel!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  fallbackLabel!,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
