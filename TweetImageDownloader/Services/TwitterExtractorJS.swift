import Foundation

/// 封装用于在 WKWebView 中执行推文解析的 JavaScript 核心引擎
public enum TwitterExtractorJS {
    
    /// 获取执行在 WKWebView 中抓取目标作者推文原图及预览图的 JS 代码
    public static var extractionScript: String {
        return """
        (function() {
            try {
                // 1. 从当前 URL 提取目标作者用户名 (例如: https://x.com/limboprossr/status/12345)
                var pathParts = window.location.pathname.split('/').filter(Boolean);
                var targetUsername = "";
                if (pathParts.length >= 1) {
                    targetUsername = pathParts[0].toLowerCase();
                }
                
                // 2. 遍历推文容器，过滤属于目标作者的主推文和作者评论区连贴
                var allCards = document.querySelectorAll('[data-testid="cellInnerDiv"]');
                var extractedImages = [];
                var seenUrls = new Set();
                
                // 辅助函数：尝试从 React 内部 Fiber/Props 或全局状态深度提取该 media ID 上传时的真实扩展名（png / jpg）
                function searchMediaExtensionInObj(obj, targetId, depth) {
                    if (!obj || depth > 8 || typeof obj !== 'object') return null;
                    if (obj.media_url_https && typeof obj.media_url_https === 'string') {
                        if (obj.media_url_https.indexOf(targetId) !== -1) {
                            var lower = obj.media_url_https.toLowerCase();
                            if (lower.indexOf('.png') !== -1 || lower.indexOf('format=png') !== -1) return 'png';
                            if (lower.indexOf('.jpg') !== -1 || lower.indexOf('.jpeg') !== -1 || lower.indexOf('format=jpg') !== -1) return 'jpg';
                        }
                    }
                    if (Array.isArray(obj)) {
                        for (var i = 0; i < obj.length; i++) {
                            var res = searchMediaExtensionInObj(obj[i], targetId, depth + 1);
                            if (res) return res;
                        }
                    } else {
                        for (var k in obj) {
                            if (k === 'memoizedProps' || k === 'return' || k === 'child' || k === 'media' || k === 'extended_entities' || k === 'entities' || k === 'tweet' || k === 'legacy' || k === 'card' || k === 'photo') {
                                var res2 = searchMediaExtensionInObj(obj[k], targetId, depth + 1);
                                if (res2) return res2;
                            }
                        }
                    }
                    return null;
                }

                function getOriginalFormat(imgElem, mediaId) {
                    if (!mediaId) return null;
                    
                    // 1. 尝试向上遍历元素及推文容器卡片的 React 内部 Fiber 节点与属性
                    var curr = imgElem;
                    for (var depth = 0; depth < 10 && curr; depth++) {
                        var keys = Object.keys(curr);
                        for (var i = 0; i < keys.length; i++) {
                            var key = keys[i];
                            if (key.indexOf('__reactProps$') === 0 || key.indexOf('__reactFiber$') === 0) {
                                try {
                                    var foundExt = searchMediaExtensionInObj(curr[key], mediaId, 0);
                                    if (foundExt) return foundExt;
                                } catch (e) {}
                            }
                        }
                        curr = curr.parentElement;
                    }
                    
                    // 2. 检查 window.__INITIAL_STATE__ 页面初始化全局媒体缓存
                    try {
                        if (window.__INITIAL_STATE__ && window.__INITIAL_STATE__.entities && window.__INITIAL_STATE__.entities.media) {
                            var medias = window.__INITIAL_STATE__.entities.media;
                            for (var mKey in medias) {
                                if (mKey.indexOf(mediaId) !== -1 || (medias[mKey].media_url_https && medias[mKey].media_url_https.indexOf(mediaId) !== -1)) {
                                    var urlStr = medias[mKey].media_url_https || "";
                                    if (urlStr.toLowerCase().endsWith('.png') || urlStr.toLowerCase().indexOf('format=png') !== -1) return 'png';
                                    if (urlStr.toLowerCase().endsWith('.jpg') || urlStr.toLowerCase().indexOf('format=jpg') !== -1) return 'jpg';
                                }
                            }
                        }
                    } catch (e) {}
                    
                    return null;
                }

                function cleanImageUrl(url, realFormat) {
                    var cleaned = url.replace(/&?name=[^&]+/ig, '');
                    // 如果探测到画师上传的是无损 png 原图，或者 URL 本身是 png
                    if (realFormat === 'png' || /format=png/i.test(cleaned) || /\.png($|\?)/i.test(cleaned)) {
                        if (/format=webp/i.test(cleaned)) {
                            cleaned = cleaned.replace(/format=webp/ig, 'format=png');
                        } else if (/format=jpg/i.test(cleaned)) {
                            cleaned = cleaned.replace(/format=jpg/ig, 'format=png');
                        } else if (cleaned.indexOf('format=') === -1 && cleaned.indexOf('?') !== -1) {
                            cleaned += '&format=png';
                        }
                    } else {
                        // 否则默认转换 webp 为 jpg 避免有损 webp
                        cleaned = cleaned.replace(/format=webp/ig, 'format=jpg');
                    }
                    return cleaned;
                }
                
                function isAuthorCard(card, username) {
                    if (!username) return true;
                    var links = card.querySelectorAll('a[href*="/status/"]');
                    for (var i = 0; i < links.length; i++) {
                        var href = links[i].getAttribute('href') || "";
                        if (href.toLowerCase().indexOf('/' + username + '/status/') !== -1) {
                            return true;
                        }
                    }
                    // 额外检查账号名字展示区
                    var userLinks = card.querySelectorAll('a[role="link"]');
                    for (var j = 0; j < userLinks.length; j++) {
                        var text = userLinks[j].textContent || "";
                        if (text.toLowerCase() === '@' + username) {
                            return true;
                        }
                    }
                    return false;
                }

                // 遍历卡片
                for (var i = 0; i < allCards.length; i++) {
                    var card = allCards[i];
                    
                    // 判断该推文卡片是否为目标作者发帖或连帖
                    if (targetUsername && !isAuthorCard(card, targetUsername)) {
                        continue;
                    }
                    
                    // 抓取该推文卡片内所有配图 (排除头像与 Emoji)
                    var imgs = card.querySelectorAll("img[src*='twimg.com/media/'], img[src*='name=']");
                    for (var k = 0; k < imgs.length; k++) {
                        var img = imgs[k];
                        var src = img.src || "";
                        
                        // 过滤头像、系统图标与非推文配图
                        if (src.indexOf('profile_images') !== -1 || src.indexOf('emoji') !== -1 || src.indexOf('twimg.com/media/') === -1) {
                            continue;
                        }
                        
                        // 提取该图片的推特媒体 ID
                        var mediaIdMatch = src.match(/twimg\.com\/media\/([^?&.\/]+)/i);
                        var mediaId = mediaIdMatch ? mediaIdMatch[1] : null;
                        
                        // 深度探测该推特媒体实际上传时的扩展格式
                        var realFormat = getOriginalFormat(img, mediaId);
                        
                        var baseUrl = cleanImageUrl(src, realFormat);
                        if (seenUrls.has(baseUrl)) {
                            continue;
                        }
                        seenUrls.add(baseUrl);
                        
                        // 构造中等清晰度预览图与原始最高分辨率 (name=orig) 原图 URL
                        var previewURL = baseUrl + (baseUrl.indexOf('?') !== -1 ? '&name=medium' : '?name=medium');
                        var originalURL = baseUrl + (baseUrl.indexOf('?') !== -1 ? '&name=orig' : '?name=orig');
                        
                        extractedImages.push({
                            "previewURL": previewURL,
                            "originalURL": originalURL,
                            "authorUsername": targetUsername || "unknown"
                        });
                    }
                }
                
                return JSON.stringify({
                    "success": true,
                    "author": targetUsername,
                    "count": extractedImages.length,
                    "images": extractedImages
                });
            } catch (err) {
                return JSON.stringify({
                    "success": false,
                    "error": err.toString()
                });
            }
        })();
        """
    }
}
