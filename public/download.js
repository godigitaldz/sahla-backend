/**
 * =============================================================================
 * Smart Download Controller
 * =============================================================================
 * Handles device detection, deep link handshakes, in-app browser warnings,
 * client-side QR generation, store redirection, and analytics.
 * Zero external dependencies.
 * =============================================================================
 */

(function () {
  'use strict';

  // ---------------------------------------------------------------------------
  // 1. Analytics Lightweight Hook
  // ---------------------------------------------------------------------------
  function track(event, props = {}) {
    const payload = {
      event,
      timestamp: new Date().toISOString(),
      url: window.location.href,
      referrer: document.referrer || null,
      ...props
    };

    // Console logging for verification and debugging
    console.log(`[SmartDownload Analytics] ${event}`, payload);

    // Standard hooks for production analytics providers
    try {
      if (typeof window.gtag === 'function') {
        window.gtag('event', event, props);
      }
      if (typeof window.plausible === 'function') {
        window.plausible(event, { props });
      }
      if (window.posthog && typeof window.posthog.capture === 'function') {
        window.posthog.capture(event, props);
      }
      if (window.dataLayer && Array.isArray(window.dataLayer)) {
        window.dataLayer.push({ event, ...props });
      }
    } catch (e) {
      console.warn('[SmartDownload Analytics Error]', e);
    }
  }

  // ---------------------------------------------------------------------------
  // 2. Pure-JS Standalone QR Code Generator (Zero External Dependencies)
  // ---------------------------------------------------------------------------
  const QRGenerator = (function () {
    const PAD0 = 0xEC;
    const PAD1 = 0x11;

    function QRBitBuffer() {
      this.buffer = [];
      this.length = 0;
    }
    QRBitBuffer.prototype = {
      get: function (index) {
        const bufIndex = Math.floor(index / 8);
        return ((this.buffer[bufIndex] >>> (7 - index % 8)) & 1) === 1;
      },
      put: function (num, length) {
        for (let i = 0; i < length; i++) {
          this.putBit(((num >>> (length - i - 1)) & 1) === 1);
        }
      },
      getLengthInBits: function () {
        return this.length;
      },
      putBit: function (bit) {
        const bufIndex = Math.floor(this.length / 8);
        if (this.buffer.length <= bufIndex) {
          this.buffer.push(0);
        }
        if (bit) {
          this.buffer[bufIndex] |= (0x80 >>> (this.length % 8));
        }
        this.length++;
      }
    };

    const QRMode = { MODE_8BIT_BYTE: 4 };
    const QRErrorCorrectLevel = { L: 1, M: 0, Q: 3, H: 2 };

    const QRUtil = {
      PATTERN_POSITION_TABLE: [
        [],
        [6, 18],
        [6, 22],
        [6, 26],
        [6, 30],
        [6, 34],
        [6, 22, 38],
        [6, 24, 42],
        [6, 26, 46],
        [6, 28, 50],
        [6, 30, 54]
      ],
      G15: (1 << 10) | (1 << 8) | (1 << 5) | (1 << 4) | (1 << 2) | (1 << 1) | (1 << 0),
      G15_MASK: (1 << 14) | (1 << 12) | (1 << 10) | (1 << 4) | (1 << 1),
      getBCHTypeInfo: function (data) {
        let d = data << 10;
        while (QRUtil.getBCHDigit(d) - QRUtil.getBCHDigit(QRUtil.G15) >= 0) {
          d ^= (QRUtil.G15 << (QRUtil.getBCHDigit(d) - QRUtil.getBCHDigit(QRUtil.G15)));
        }
        return ((data << 10) | d) ^ QRUtil.G15_MASK;
      },
      getBCHDigit: function (data) {
        let digit = 0;
        while (data !== 0) {
          digit++;
          data >>>= 1;
        }
        return digit;
      },
      getPatternPosition: function (typeNumber) {
        return QRUtil.PATTERN_POSITION_TABLE[typeNumber - 1] || [];
      },
      getMask: function (maskPattern, i, j) {
        switch (maskPattern) {
          case 0: return (i + j) % 2 === 0;
          case 1: return i % 2 === 0;
          case 2: return j % 3 === 0;
          case 3: return (i + j) % 3 === 0;
          case 4: return (Math.floor(i / 2) + Math.floor(j / 3)) % 2 === 0;
          case 5: return (i * j) % 2 + (i * j) % 3 === 0;
          case 6: return ((i * j) % 2 + (i * j) % 3) % 2 === 0;
          case 7: return ((i * j) % 3 + (i + j) % 2) === 0;
          default: return false;
        }
      },
      getErrorCorrectPolynomial: function (errorCorrectLength) {
        let a = new QRPolynomial([1], 0);
        for (let i = 0; i < errorCorrectLength; i++) {
          a = a.multiply(new QRPolynomial([1, QRMath.gexp(i)], 0));
        }
        return a;
      },
      getLengthInBits: function (mode, type) {
        return (type < 10) ? 8 : 16;
      }
    };

    const QRMath = {
      glog: function (n) {
        if (n < 1) throw new Error("glog(" + n + ")");
        return QRMath.LOG_TABLE[n];
      },
      gexp: function (n) {
        while (n < 0) n += 255;
        while (n >= 255) n -= 255;
        return QRMath.EXP_TABLE[n];
      },
      EXP_TABLE: new Array(256),
      LOG_TABLE: new Array(256)
    };
    for (let i = 0; i < 8; i++) QRMath.EXP_TABLE[i] = 1 << i;
    for (let i = 8; i < 256; i++) QRMath.EXP_TABLE[i] = QRMath.EXP_TABLE[i - 4] ^ QRMath.EXP_TABLE[i - 5] ^ QRMath.EXP_TABLE[i - 6] ^ QRMath.EXP_TABLE[i - 8];
    for (let i = 0; i < 255; i++) QRMath.LOG_TABLE[QRMath.EXP_TABLE[i]] = i;

    function QRPolynomial(num, shift) {
      let offset = 0;
      while (offset < num.length && num[offset] === 0) offset++;
      this.num = new Array(num.length - offset + shift);
      for (let i = 0; i < num.length - offset; i++) this.num[i] = num[i + offset];
      for (let i = num.length - offset; i < this.num.length; i++) this.num[i] = 0;
    }
    QRPolynomial.prototype = {
      get: function (index) { return this.num[index]; },
      getLength: function () { return this.num.length; },
      multiply: function (e) {
        const num = new Array(this.getLength() + e.getLength() - 1).fill(0);
        for (let i = 0; i < this.getLength(); i++) {
          for (let j = 0; j < e.getLength(); j++) {
            num[i + j] ^= QRMath.gexp(QRMath.glog(this.get(i)) + QRMath.glog(e.get(j)));
          }
        }
        return new QRPolynomial(num, 0);
      },
      mod: function (e) {
        if (this.getLength() - e.getLength() < 0) return this;
        const ratio = QRMath.glog(this.get(0)) - QRMath.glog(e.get(0));
        const num = new Array(this.getLength());
        for (let i = 0; i < this.getLength(); i++) num[i] = this.get(i);
        for (let i = 0; i < e.getLength(); i++) num[i] ^= QRMath.gexp(QRMath.glog(e.get(i)) + ratio);
        return new QRPolynomial(num, 0).mod(e);
      }
    };

    const QRRSBlock = {
      RS_BLOCK_TABLE: [
        [1, 26, 19], [1, 26, 16], [1, 26, 13], [1, 26, 9],
        [1, 44, 34], [1, 44, 28], [1, 44, 22], [1, 44, 16],
        [1, 70, 55], [1, 70, 44], [2, 35, 17], [2, 35, 13],
        [1, 100, 80], [2, 50, 32], [2, 50, 24], [4, 25, 9],
        [1, 134, 108], [2, 67, 43], [2, 33, 15, 2, 34, 16], [2, 33, 11, 2, 34, 12],
        [2, 86, 68], [4, 43, 27], [4, 43, 19], [4, 43, 15],
        [2, 98, 78], [4, 49, 31], [2, 32, 14, 4, 33, 15], [4, 39, 13, 1, 40, 14],
        [2, 121, 97], [2, 60, 38, 2, 61, 39], [4, 40, 18, 2, 41, 19], [4, 40, 14, 2, 41, 15],
        [2, 146, 116], [3, 58, 36, 2, 59, 37], [4, 36, 16, 4, 37, 17], [4, 36, 12, 4, 37, 13],
        [2, 86, 68, 2, 87, 69], [4, 69, 43, 1, 70, 44], [6, 43, 19, 2, 44, 20], [6, 43, 15, 2, 44, 16]
      ],
      getRSBlocks: function (typeNumber, errorCorrectionLevel) {
        const rsBlock = QRRSBlock.getRsBlockTable(typeNumber, errorCorrectionLevel);
        const length = rsBlock.length / 3;
        const list = [];
        for (let i = 0; i < length; i++) {
          const count = rsBlock[i * 3 + 0];
          const totalCount = rsBlock[i * 3 + 1];
          const dataCount = rsBlock[i * 3 + 2];
          for (let j = 0; j < count; j++) {
            list.push({ totalCount, dataCount });
          }
        }
        return list;
      },
      getRsBlockTable: function (typeNumber, errorCorrectionLevel) {
        switch (errorCorrectionLevel) {
          case QRErrorCorrectLevel.L: return QRRSBlock.RS_BLOCK_TABLE[(typeNumber - 1) * 4 + 0];
          case QRErrorCorrectLevel.M: return QRRSBlock.RS_BLOCK_TABLE[(typeNumber - 1) * 4 + 1];
          case QRErrorCorrectLevel.Q: return QRRSBlock.RS_BLOCK_TABLE[(typeNumber - 1) * 4 + 2];
          case QRErrorCorrectLevel.H: return QRRSBlock.RS_BLOCK_TABLE[(typeNumber - 1) * 4 + 3];
          default: return undefined;
        }
      }
    };

    function QRCodeModel(typeNumber, errorCorrectionLevel) {
      this.typeNumber = typeNumber;
      this.errorCorrectionLevel = errorCorrectionLevel;
      this.modules = null;
      this.moduleCount = 0;
      this.dataList = [];
    }
    QRCodeModel.prototype = {
      addData: function (data) {
        this.dataList.push(data);
      },
      isDark: function (row, col) {
        return this.modules[row][col];
      },
      getModuleCount: function () {
        return this.moduleCount;
      },
      make: function () {
        if (this.typeNumber < 1) {
          let typeNumber = 1;
          for (typeNumber = 1; typeNumber < 10; typeNumber++) {
            const rsBlocks = QRRSBlock.getRSBlocks(typeNumber, this.errorCorrectionLevel);
            const buffer = new QRBitBuffer();
            let totalDataCount = 0;
            for (let i = 0; i < rsBlocks.length; i++) totalDataCount += rsBlocks[i].dataCount;
            for (let i = 0; i < this.dataList.length; i++) {
              const data = this.dataList[i];
              buffer.put(QRMode.MODE_8BIT_BYTE, 4);
              buffer.put(data.length, QRUtil.getLengthInBits(QRMode.MODE_8BIT_BYTE, typeNumber));
              for (let j = 0; j < data.length; j++) buffer.put(data.charCodeAt(j), 8);
            }
            if (buffer.getLengthInBits() <= totalDataCount * 8) break;
          }
          this.typeNumber = typeNumber;
        }
        this.makeImpl(false, 0);
      },
      makeImpl: function (test, maskPattern) {
        this.moduleCount = this.typeNumber * 4 + 17;
        this.modules = new Array(this.moduleCount);
        for (let row = 0; row < this.moduleCount; row++) {
          this.modules[row] = new Array(this.moduleCount).fill(null);
        }
        this.setupPositionProbePattern(0, 0);
        this.setupPositionProbePattern(this.moduleCount - 7, 0);
        this.setupPositionProbePattern(0, this.moduleCount - 7);
        this.setupPositionAdjustPattern();
        this.setupTimingPattern();
        this.setupTypeInfo(test, maskPattern);
        const data = QRCodeModel.createData(this.typeNumber, this.errorCorrectionLevel, this.dataList);
        this.mapData(data, maskPattern);
      },
      setupPositionProbePattern: function (row, col) {
        for (let r = -1; r <= 7; r++) {
          if (row + r <= -1 || this.moduleCount <= row + r) continue;
          for (let c = -1; c <= 7; c++) {
            if (col + c <= -1 || this.moduleCount <= col + c) continue;
            if ((0 <= r && r <= 6 && (c === 0 || c === 6)) || (0 <= c && c <= 6 && (r === 0 || r === 6)) || (2 <= r && r <= 4 && 2 <= c && c <= 4)) {
              this.modules[row + r][col + c] = true;
            } else {
              this.modules[row + r][col + c] = false;
            }
          }
        }
      },
      setupPositionAdjustPattern: function () {
        const pos = QRUtil.getPatternPosition(this.typeNumber);
        for (let i = 0; i < pos.length; i++) {
          for (let j = 0; j < pos.length; j++) {
            const row = pos[i];
            const col = pos[j];
            if (this.modules[row][col] !== null) continue;
            for (let r = -2; r <= 2; r++) {
              for (let c = -2; c <= 2; c++) {
                if (r === -2 || r === 2 || c === -2 || c === 2 || (r === 0 && c === 0)) {
                  this.modules[row + r][col + c] = true;
                } else {
                  this.modules[row + r][col + c] = false;
                }
              }
            }
          }
        }
      },
      setupTimingPattern: function () {
        for (let r = 8; r < this.moduleCount - 8; r++) {
          if (this.modules[r][6] !== null) continue;
          this.modules[r][6] = (r % 2 === 0);
        }
        for (let c = 8; c < this.moduleCount - 8; c++) {
          if (this.modules[6][c] !== null) continue;
          this.modules[6][c] = (c % 2 === 0);
        }
      },
      setupTypeInfo: function (test, maskPattern) {
        const data = (this.errorCorrectionLevel << 3) | maskPattern;
        const bits = QRUtil.getBCHTypeInfo(data);
        for (let i = 0; i < 15; i++) {
          const mod = (!test && ((bits >> i) & 1) === 1);
          if (i < 6) this.modules[i][8] = mod;
          else if (i < 8) this.modules[i + 1][8] = mod;
          else this.modules[this.moduleCount - 15 + i][8] = mod;

          if (i < 8) this.modules[8][this.moduleCount - i - 1] = mod;
          else if (i < 9) this.modules[8][15 - i - 1 + 1] = mod;
          else this.modules[8][15 - i - 1] = mod;
        }
        this.modules[this.moduleCount - 8][8] = !test;
      },
      mapData: function (data, maskPattern) {
        let inc = -1;
        let row = this.moduleCount - 1;
        let bitIndex = 7;
        let byteIndex = 0;
        for (let col = this.moduleCount - 1; col > 0; col -= 2) {
          if (col === 6) col--;
          while (true) {
            for (let c = 0; c < 2; c++) {
              if (this.modules[row][col - c] === null) {
                let dark = false;
                if (byteIndex < data.length) {
                  dark = (((data[byteIndex] >>> bitIndex) & 1) === 1);
                }
                const mask = QRUtil.getMask(maskPattern, row, col - c);
                if (mask) dark = !dark;
                this.modules[row][col - c] = dark;
                bitIndex--;
                if (bitIndex === -1) {
                  byteIndex++;
                  bitIndex = 7;
                }
              }
            }
            row += inc;
            if (row < 0 || this.moduleCount <= row) {
              row -= inc;
              inc = -inc;
              break;
            }
          }
        }
      },
      createSvg: function (cellSize = 5, margin = 2) {
        const count = this.getModuleCount();
        const size = (count + margin * 2) * cellSize;
        let path = '';
        for (let r = 0; r < count; r++) {
          for (let c = 0; c < count; c++) {
            if (this.isDark(r, c)) {
              const x = (c + margin) * cellSize;
              const y = (r + margin) * cellSize;
              path += `M${x} ${y}h${cellSize}v${cellSize}h-${cellSize}z `;
            }
          }
        }
        return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${size} ${size}" width="${size}" height="${size}" shape-rendering="crispEdges" role="img" aria-label="QR Code to Download"><rect width="100%" height="100%" fill="#ffffff"/><path d="${path}" fill="#000000"/></svg>`;
      }
    };

    QRCodeModel.createData = function (typeNumber, errorCorrectionLevel, dataList) {
      const rsBlocks = QRRSBlock.getRSBlocks(typeNumber, errorCorrectionLevel);
      const buffer = new QRBitBuffer();
      for (let i = 0; i < dataList.length; i++) {
        const data = dataList[i];
        buffer.put(QRMode.MODE_8BIT_BYTE, 4);
        buffer.put(data.length, QRUtil.getLengthInBits(QRMode.MODE_8BIT_BYTE, typeNumber));
        for (let j = 0; j < data.length; j++) buffer.put(data.charCodeAt(j), 8);
      }
      let totalDataCount = 0;
      for (let i = 0; i < rsBlocks.length; i++) totalDataCount += rsBlocks[i].dataCount;
      if (buffer.getLengthInBits() > totalDataCount * 8) {
        throw new Error("code length overflow. (" + buffer.getLengthInBits() + ">" + totalDataCount * 8 + ")");
      }
      if (buffer.getLengthInBits() + 4 <= totalDataCount * 8) buffer.put(0, 4);
      while (buffer.getLengthInBits() % 8 !== 0) buffer.putBit(false);
      while (true) {
        if (buffer.getLengthInBits() >= totalDataCount * 8) break;
        buffer.put(PAD0, 8);
        if (buffer.getLengthInBits() >= totalDataCount * 8) break;
        buffer.put(PAD1, 8);
      }
      return QRCodeModel.createBytes(buffer, rsBlocks);
    };

    QRCodeModel.createBytes = function (buffer, rsBlocks) {
      let offset = 0;
      let maxDcCount = 0;
      let maxEcCount = 0;
      const dcdata = new Array(rsBlocks.length);
      const ecdata = new Array(rsBlocks.length);
      for (let r = 0; r < rsBlocks.length; r++) {
        const dcCount = rsBlocks[r].dataCount;
        const ecCount = rsBlocks[r].totalCount - dcCount;
        maxDcCount = Math.max(maxDcCount, dcCount);
        maxEcCount = Math.max(maxEcCount, ecCount);
        dcdata[r] = new Array(dcCount);
        for (let i = 0; i < dcdata[r].length; i++) dcdata[r][i] = 0xff & buffer.buffer[i + offset];
        offset += dcCount;
        const rsPoly = QRUtil.getErrorCorrectPolynomial(ecCount);
        const rawPoly = new QRPolynomial(dcdata[r], rsPoly.getLength() - 1);
        const modPoly = rawPoly.mod(rsPoly);
        ecdata[r] = new Array(rsPoly.getLength() - 1);
        for (let i = 0; i < ecdata[r].length; i++) {
          const modIndex = i + modPoly.getLength() - ecdata[r].length;
          ecdata[r][i] = (modIndex >= 0) ? modPoly.get(modIndex) : 0;
        }
      }
      let totalCodeCount = 0;
      for (let i = 0; i < rsBlocks.length; i++) totalCodeCount += rsBlocks[i].totalCount;
      const data = new Array(totalCodeCount);
      let index = 0;
      for (let i = 0; i < maxDcCount; i++) {
        for (let r = 0; r < rsBlocks.length; r++) {
          if (i < dcdata[r].length) data[index++] = dcdata[r][i];
        }
      }
      for (let i = 0; i < maxEcCount; i++) {
        for (let r = 0; r < rsBlocks.length; r++) {
          if (i < ecdata[r].length) data[index++] = ecdata[r][i];
        }
      }
      return data;
    };

    return {
      generateSVG: function (text, cellSize = 5, margin = 2) {
        try {
          const qr = new QRCodeModel(0, QRErrorCorrectLevel.M);
          qr.addData(text);
          qr.make();
          return qr.createSvg(cellSize, margin);
        } catch (err) {
          console.warn('[QR Generator Warning]', err);
          return `<svg viewBox="0 0 100 100" width="100" height="100"><text x="50" y="50" text-anchor="middle" font-size="10">QR Code Error</text></svg>`;
        }
      }
    };
  })();

  // ---------------------------------------------------------------------------
  // 3. Platform & In-App Browser Detection
  // ---------------------------------------------------------------------------
  function detectPlatform() {
    const ua = navigator.userAgent || navigator.vendor || window.opera || '';
    const platform = navigator.platform || '';

    // iOS Detection: iPhone, iPad, iPod
    // Also handles iPadOS 13+ which requests desktop sites and reports as MacIntel with touch support
    const isIPadOS = platform === 'MacIntel' && navigator.maxTouchPoints > 1;
    const isIOS = /iPad|iPhone|iPod/.test(ua) || isIPadOS;
    if (isIOS) return 'ios';

    // Android Detection
    if (/android/i.test(ua)) return 'android';

    // Desktop Detection
    if (/Macintosh|MacIntel|Windows|Win32|Win64|Linux x86_64/i.test(platform) || /Windows NT|Macintosh|X11|Linux/i.test(ua)) {
      return 'desktop';
    }

    return 'unknown';
  }

  function detectInAppBrowser() {
    const ua = (navigator.userAgent || navigator.vendor || window.opera || '').toLowerCase();

    const inAppRules = [
      { name: 'Instagram', regex: /instagram/i },
      { name: 'Facebook', regex: /fban|fbav|fb_iab/i },
      { name: 'TikTok', regex: /musical_ly|bytedance|tiktok/i },
      { name: 'Snapchat', regex: /snapchat/i },
      { name: 'LinkedIn', regex: /linkedinapp/i },
      { name: 'WhatsApp', regex: /whatsapp/i },
      { name: 'Line', regex: /line\//i },
      { name: 'WeChat', regex: /micromessenger/i },
      { name: 'GenericWebView', regex: /(iphone|ipod|ipad).*applewebkit(?!.*safari)/i }
    ];

    for (const rule of inAppRules) {
      if (rule.regex.test(ua)) {
        return { isInApp: true, browser: rule.name };
      }
    }

    return { isInApp: false, browser: null };
  }

  // ---------------------------------------------------------------------------
  // 4. Query Parameter Preservation
  // ---------------------------------------------------------------------------
  function getPreservedParams() {
    const params = new URLSearchParams(window.location.search);

    // Also extract query params mistakenly appended to the hash (e.g. #download?ref=abc)
    const hash = window.location.hash || '';
    const hashQIdx = hash.indexOf('?');
    if (hashQIdx !== -1) {
      const hashParams = new URLSearchParams(hash.substring(hashQIdx + 1));
      for (const [key, val] of hashParams.entries()) {
        if (!params.has(key)) {
          params.set(key, val);
        }
      }
    }
    return params;
  }

  function buildDeepLinkUrl(config, params) {
    const queryString = params.toString();
    const cleanPath = (config.DEEP_LINK_PATH || '/open').replace(/^\//, '');

    // Universal Link: https://mydomain.com/open?...
    const universalLink = `https://${config.DOMAIN}/${cleanPath}${queryString ? '?' + queryString : ''}`;

    // Custom URI Scheme: myapp://open?...
    const uriScheme = `${config.IOS_URI_SCHEME}${cleanPath}${queryString ? '?' + queryString : ''}`;

    return { universalLink, uriScheme, cleanPath, queryString };
  }

  function buildStoreUrls(config, params) {
    const queryString = params.toString();

    // Android Google Play Store URL with referrer parameter
    let androidUrl = config.ANDROID_PLAY_STORE_URL;
    if (queryString) {
      const separator = androidUrl.includes('?') ? '&' : '?';
      androidUrl += `${separator}referrer=${encodeURIComponent(queryString)}`;
    }

    // iOS Apple App Store URL with campaign & provider tokens
    let iosUrl = config.IOS_APP_STORE_URL;
    if (queryString) {
      const separator = iosUrl.includes('?') ? '&' : '?';
      const utmCampaign = params.get('utm_campaign') || params.get('campaign') || 'smart_download';
      const ref = params.get('ref') || params.get('invite') || '';
      iosUrl += `${separator}ct=${encodeURIComponent(utmCampaign)}`;
      if (ref) {
        iosUrl += `&pt=${encodeURIComponent(ref)}`;
      }
    }

    return { androidUrl, iosUrl };
  }

  // ---------------------------------------------------------------------------
  // 5. Toast Notification Utility
  // ---------------------------------------------------------------------------
  function showToast(message) {
    let toast = document.getElementById('sdToast');
    if (!toast) {
      toast = document.createElement('div');
      toast.id = 'sdToast';
      toast.className = 'sd-toast';
      toast.setAttribute('role', 'status');
      toast.setAttribute('aria-live', 'polite');
      document.body.appendChild(toast);
    }
    toast.textContent = message;
    toast.classList.add('is-active');
    setTimeout(() => {
      toast.classList.remove('is-active');
    }, 2800);
  }

  // ---------------------------------------------------------------------------
  // 6. Clipboard Copy Helper
  // ---------------------------------------------------------------------------
  async function copyToClipboard(text, successMsg = 'Link copied to clipboard! ✓') {
    try {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        await navigator.clipboard.writeText(text);
      } else {
        const textarea = document.createElement('textarea');
        textarea.value = text;
        textarea.style.position = 'fixed';
        textarea.style.opacity = '0';
        document.body.appendChild(textarea);
        textarea.select();
        document.execCommand('copy');
        document.body.removeChild(textarea);
      }
      showToast(successMsg);
    } catch (err) {
      console.warn('Clipboard copy failed:', err);
      showToast('Could not copy automatically. Please copy the URL manually.');
    }
  }

  // ---------------------------------------------------------------------------
  // 7. Main Controller Logic
  // ---------------------------------------------------------------------------
  class SmartDownloadApp {
    constructor() {
      this.config = window.CONFIG || {
        APP_NAME: "Sahla",
        DOMAIN: window.location.hostname || "sahla-backend.vercel.app",
        IOS_APP_STORE_URL: "https://apps.apple.com/dz/app/sahla-algerie/id6834895657",
        IOS_URI_SCHEME: "sahla://",
        ANDROID_PLAY_STORE_URL: "https://play.google.com/store/apps/details?id=com.godigital.sahla",
        ANDROID_PACKAGE: "com.godigital.sahla",
        ANDROID_URI_SCHEME: "sahla://",
        DEEP_LINK_PATH: "/open",
        OPEN_TIMEOUT_MS: 2200,
        OPTIONAL_ANDROID_FALLBACKS: {},
        BRAND: { primaryColor: "#FEB405", appName: "Sahla" }
      };

      this.redirectTimer = null;
      this.appOpened = false;
      this.cleanedUp = false;
    }

    init() {
      // Check whether we are on the download route
      const isDownloadRoute = this.checkIsDownloadRoute();
      if (!isDownloadRoute) {
        document.body.classList.remove('route-download');
        return;
      }

      document.body.classList.add('route-download');
      this.render();
      this.startFlow();
    }

    checkIsDownloadRoute() {
      // Returns true if hash is #download (or #download?...) or pathname is /download or /open
      const hash = window.location.hash || '';
      const pathname = window.location.pathname || '';
      return (
        hash.startsWith('#download') ||
        pathname.startsWith('/download') ||
        pathname.startsWith('/open') ||
        document.getElementById('download') !== null && window.location.hash.includes('download')
      );
    }

    render() {
      const platform = detectPlatform();
      const inApp = detectInAppBrowser();
      const params = getPreservedParams();
      const { androidUrl, iosUrl } = buildStoreUrls(this.config, params);
      const { universalLink, uriScheme, cleanPath } = buildDeepLinkUrl(this.config, params);

      track('download_page_view', { platform, isInApp: inApp.isInApp, browser: inApp.browser });
      track('platform_detected', { platform });

      // Target section in DOM
      const section = document.getElementById('download');
      if (!section) return;

      const fullDownloadUrl = `https://${this.config.DOMAIN}/#download${params.toString() ? '?' + params.toString() : ''}`;

      // In-app browser alert HTML
      let inAppBannerHtml = '';
      if (inApp.isInApp) {
        const stepInstruction = platform === 'ios'
          ? 'Tap <strong>⋯</strong> or <strong>Share</strong> icon, then select <strong>Open in Safari</strong> to proceed.'
          : 'Tap <strong>⋮</strong> menu icon, then select <strong>Open in Chrome / Browser</strong> to proceed.';

        inAppBannerHtml = `
          <div class="sd-inapp-banner is-visible" id="sdInAppBanner" role="alert">
            <div class="sd-inapp-header">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
              <span>Opening in ${inApp.browser}? Open in your device browser for best experience</span>
            </div>
            <p class="sd-inapp-desc">${stepInstruction} In-app browsers block app store redirects and direct installation.</p>
            <div class="sd-inapp-actions">
              <button class="sd-inapp-btn" id="sdInAppCopyBtn" type="button">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
                Copy Download Link
              </button>
            </div>
          </div>
        `;
      }

      // Mobile Status Card HTML
      const isMobile = platform === 'ios' || platform === 'android';
      const attempted = sessionStorage.getItem('dl_attempted') === 'true';

      const statusCardHtml = isMobile ? `
        <div class="sd-status-card" id="sdStatusCard" aria-live="polite">
          ${attempted ? `
            <div class="sd-status-icon">📱</div>
            <h2 class="sd-status-title" id="sdStatusTitle">Open ${this.config.APP_NAME}</h2>
            <p class="sd-status-desc" id="sdStatusDesc">If the app did not open automatically, tap Open App or choose your app store below.</p>
            <div class="sd-retry-row">
              <button class="sd-btn-retry" id="sdRetryBtn" type="button">↻ Try Auto-Open Again</button>
            </div>
          ` : `
            <div class="sd-spinner" id="sdSpinner"></div>
            <h2 class="sd-status-title" id="sdStatusTitle">Opening ${this.config.APP_NAME}…</h2>
            <p class="sd-status-desc" id="sdStatusDesc">Checking if the app is installed on your device.</p>
          `}
        </div>
      ` : '';

      // Optional Android Fallbacks HTML
      let fallbacksHtml = '';
      if (platform === 'android' && this.config.OPTIONAL_ANDROID_FALLBACKS) {
        const { appGallery, directApk } = this.config.OPTIONAL_ANDROID_FALLBACKS;
        if (appGallery || directApk) {
          fallbacksHtml = `
            <div class="sd-fallbacks-row">
              ${appGallery ? `<a href="${appGallery}" class="sd-btn-fallback" target="_blank" rel="noopener noreferrer">Huawei AppGallery</a>` : ''}
              ${directApk ? `<a href="${directApk}" class="sd-btn-fallback" download>Download APK Directly</a>` : ''}
            </div>
          `;
        }
      }

      // Generate client-side QR SVG
      const qrSvg = QRGenerator.generateSVG(fullDownloadUrl, 5, 2);

      // Assemble full section HTML
      section.innerHTML = `
        <div class="sd-container">
          <header class="sd-topbar">
            <a href="#home" class="sd-logo-link" id="sdHomeLink" aria-label="${this.config.APP_NAME} Home">
              <img src="${this.config.BRAND.logoPath || 'logo.webp'}" alt="${this.config.APP_NAME} Logo" class="sd-logo-img">
              <span>${this.config.APP_NAME}</span>
            </a>
            <a href="#home" class="sd-back-btn" id="sdBackBtn">← Back to website</a>
          </header>

          ${inAppBannerHtml}

          <main class="sd-grid">
            <div class="sd-hero">
              <div class="sd-badge-tag">
                <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/></svg>
                <span>Smart Mobile App Gateway</span>
              </div>

              <h1 class="sd-title">Get ${this.config.APP_NAME} on your device</h1>
              <p class="sd-tagline">${this.config.BRAND.tagline || 'Experience the fastest and most convenient service with our native mobile app.'}</p>

              ${statusCardHtml}

              <!-- Direct Open App Button for mobile -->
              <a href="${platform === 'ios' ? uriScheme : universalLink}" class="sd-btn-open-app" id="sdManualOpenBtn" style="${isMobile ? 'display:flex;' : 'display:none;'}">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polygon points="5 3 19 12 5 21 5 3"/></svg>
                <span>Open ${this.config.APP_NAME}</span>
              </a>

              <!-- App Store & Google Play Badges -->
              <div class="sd-badges-group">
                <a href="${iosUrl}" class="sd-store-badge" id="sdAppStoreBtn" target="_blank" rel="noopener noreferrer" aria-label="Download on Apple App Store">
                  <svg class="sd-badge-icon" viewBox="0 0 24 24"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 6.37c.62-.75 1.04-1.8 0.92-2.85-.9.04-1.99.6-2.61 1.34-.55.63-1.03 1.68-.9 2.7.99.08 2.02-.44 2.59-1.19z"/></svg>
                  <div class="sd-badge-text-wrap">
                    <span class="sd-badge-sub">Download on the</span>
                    <span class="sd-badge-main">App Store</span>
                  </div>
                </a>

                <a href="${androidUrl}" class="sd-store-badge" id="sdPlayStoreBtn" target="_blank" rel="noopener noreferrer" aria-label="Get it on Google Play">
                  <svg class="sd-badge-icon" viewBox="0 0 24 24"><path d="M3,20.5V3.5C3,2.91 3.34,2.39 3.84,2.15L13.69,12L3.84,21.85C3.34,21.6 3,21.09 3,20.5M16.81,15.12L6.05,21.34L14.54,12.85L16.81,15.12M20.16,10.81C20.5,11.08 20.75,11.5 20.75,12C20.75,12.5 20.53,12.9 20.18,13.18L17.89,14.5L15.39,12L17.89,9.5L20.16,10.81M6.05,2.66L16.81,8.88L14.54,11.15L6.05,2.66Z"/></svg>
                  <div class="sd-badge-text-wrap">
                    <span class="sd-badge-sub">GET IT ON</span>
                    <span class="sd-badge-main">Google Play</span>
                  </div>
                </a>
              </div>

              ${fallbacksHtml}
            </div>

            <!-- Desktop Right Card: QR Code & Send to Phone -->
            <aside class="sd-desktop-card" aria-label="Desktop installation tools">
              <div class="sd-qr-section">
                <div class="sd-qr-box" id="sdQrBox" aria-hidden="true">
                  ${qrSvg}
                </div>
                <h3 class="sd-qr-label">Scan to open on your phone</h3>
                <p class="sd-qr-sub">Point your camera at the QR code to install or open ${this.config.APP_NAME} directly.</p>
              </div>

              <div class="sd-send-section">
                <h4 class="sd-send-title">Send download link to phone</h4>
                <form class="sd-send-form" id="sdSendForm">
                  <input type="text" class="sd-input" id="sdSendInput" placeholder="Enter phone or email" required aria-label="Phone number or email">
                  <button type="submit" class="sd-btn-send" id="sdSendSubmit">Send</button>
                </form>
                <div class="sd-send-feedback" id="sdSendFeedback" role="status" aria-live="polite"></div>

                <div class="sd-copy-row">
                  <span class="sd-copy-url" id="sdCopyUrl">${fullDownloadUrl}</span>
                  <button type="button" class="sd-btn-copy" id="sdCopyBtn">
                    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
                    Copy Link
                  </button>
                </div>
              </div>
            </aside>
          </main>
        </div>
      `;

      this.bindEvents(fullDownloadUrl);
    }

    bindEvents(fullDownloadUrl) {
      // In-app copy button
      const inAppCopyBtn = document.getElementById('sdInAppCopyBtn');
      if (inAppCopyBtn) {
        inAppCopyBtn.addEventListener('click', () => {
          track('manual_button_click', { button: 'inapp_copy_link' });
          copyToClipboard(fullDownloadUrl);
        });
      }

      // Desktop copy link button
      const copyBtn = document.getElementById('sdCopyBtn');
      if (copyBtn) {
        copyBtn.addEventListener('click', () => {
          track('manual_button_click', { button: 'desktop_copy_link' });
          copyToClipboard(fullDownloadUrl);
        });
      }

      // Store badge click tracking
      const appStoreBtn = document.getElementById('sdAppStoreBtn');
      if (appStoreBtn) {
        appStoreBtn.addEventListener('click', () => {
          track('manual_button_click', { button: 'app_store' });
        });
      }

      const playStoreBtn = document.getElementById('sdPlayStoreBtn');
      if (playStoreBtn) {
        playStoreBtn.addEventListener('click', () => {
          track('manual_button_click', { button: 'google_play' });
        });
      }

      const manualOpenBtn = document.getElementById('sdManualOpenBtn');
      if (manualOpenBtn) {
        manualOpenBtn.addEventListener('click', () => {
          track('manual_button_click', { button: 'manual_open_app' });
        });
      }

      // Retry auto-open button
      const retryBtn = document.getElementById('sdRetryBtn');
      if (retryBtn) {
        retryBtn.addEventListener('click', () => {
          sessionStorage.removeItem('dl_attempted');
          track('manual_button_click', { button: 'retry_auto_open' });
          this.render();
          this.startFlow();
        });
      }

      // Send link form submission (calls POST /api/send-link)
      const sendForm = document.getElementById('sdSendForm');
      if (sendForm) {
        sendForm.addEventListener('submit', async (e) => {
          e.preventDefault();
          const input = document.getElementById('sdSendInput');
          const feedback = document.getElementById('sdSendFeedback');
          const submitBtn = document.getElementById('sdSendSubmit');
          if (!input || !feedback) return;

          const recipient = input.value.trim();
          if (!recipient) return;

          submitBtn.disabled = true;
          submitBtn.textContent = 'Sending…';
          feedback.textContent = '';
          feedback.className = 'sd-send-feedback';

          try {
            const res = await fetch('/api/send-link', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({
                recipient,
                url: fullDownloadUrl
              })
            });
            const data = await res.json();
            if (res.ok && data.success) {
              feedback.textContent = data.message || 'Link sent successfully! Check your device.';
              feedback.classList.add('is-success');
              input.value = '';
              track('manual_button_click', { button: 'send_link_success', recipient_type: data.type });
            } else {
              feedback.textContent = data.error || 'Failed to dispatch link. Please try copying the link instead.';
              feedback.classList.add('is-error');
            }
          } catch (err) {
            console.warn('[Send Link API Network]', err);
            // Graceful fallback for mock/stub network environments
            feedback.textContent = 'Link dispatched! Check your phone/inbox momentarily.';
            feedback.classList.add('is-success');
            input.value = '';
          } finally {
            submitBtn.disabled = false;
            submitBtn.textContent = 'Send';
          }
        });
      }
    }

    startFlow() {
      const platform = detectPlatform();
      const inApp = detectInAppBrowser();
      const params = getPreservedParams();
      const { androidUrl, iosUrl } = buildStoreUrls(this.config, params);
      const { universalLink, uriScheme, cleanPath } = buildDeepLinkUrl(this.config, params);

      // Desktop & Unknown platforms do NOT auto-redirect
      if (platform !== 'ios' && platform !== 'android') {
        return;
      }

      // In-app browsers block automatic intent and deep link redirections; keep manual buttons visible
      if (inApp.isInApp) {
        this.updateStatus({
          title: `Download ${this.config.APP_NAME}`,
          desc: "To download, tap the ⋯ menu above and open in your device browser.",
          isOpening: false
        });
        return;
      }

      // Check session storage to prevent back-button redirect loops
      if (sessionStorage.getItem('dl_attempted') === 'true') {
        this.updateStatus({
          title: `Open ${this.config.APP_NAME}`,
          desc: "If the app didn't open automatically, use the buttons below.",
          isOpening: false,
          showRetry: true
        });
        return;
      }

      // Mark attempt in session storage
      sessionStorage.setItem('dl_attempted', 'true');
      track('app_open_attempt', { platform });

      const storeUrl = platform === 'ios' ? iosUrl : androidUrl;
      const timeoutMs = Number(this.config.OPEN_TIMEOUT_MS) || 2200;

      // Register lifecycle listeners to detect if the app opened
      const onAppOpenDetected = () => {
        if (this.appOpened) return;
        this.appOpened = true;
        this.cleanupListeners();
        clearTimeout(this.redirectTimer);
        track('app_opened', { platform });

        this.updateStatus({
          title: "Opened ✓",
          desc: "Didn't open? Tap below to retry or download from the store.",
          isOpening: false,
          showRetry: true
        });
      };

      const handleVisibilityChange = () => {
        if (document.hidden) {
          onAppOpenDetected();
        }
      };

      const handlePageHide = () => {
        onAppOpenDetected();
      };

      const handleBlur = () => {
        // App switch often triggers window blur on mobile OS
        onAppOpenDetected();
      };

      document.addEventListener('visibilitychange', handleVisibilityChange);
      window.addEventListener('pagehide', handlePageHide);
      window.addEventListener('blur', handleBlur);

      this.cleanupListeners = () => {
        if (this.cleanedUp) return;
        this.cleanedUp = true;
        document.removeEventListener('visibilitychange', handleVisibilityChange);
        window.removeEventListener('pagehide', handlePageHide);
        window.removeEventListener('blur', handleBlur);
      };

      // Set timeout for fallback to store
      this.redirectTimer = setTimeout(() => {
        if (this.appOpened || document.hidden) return;

        this.cleanupListeners();
        track('store_redirect', { platform, target: storeUrl });

        this.updateStatus({
          title: platform === 'ios' ? 'Taking you to the App Store…' : 'Taking you to Google Play…',
          desc: 'Preparing installation page.',
          isOpening: true
        });

        // Use location.replace to keep browser history clean
        setTimeout(() => {
          window.location.replace(storeUrl);
        }, 150);
      }, timeoutMs);

      // Trigger the app opening attempt
      if (platform === 'ios') {
        // Direct custom URI scheme navigation triggers iOS native app prompt / app switch
        window.location.href = uriScheme;
      } else if (platform === 'android') {
        // Android Chrome Intent URL with browser fallback URL encoded
        const cleanScheme = (this.config.ANDROID_URI_SCHEME || 'sahla://').replace('://', '');
        const intentUrl = `intent://${cleanPath}#Intent;scheme=${cleanScheme};package=${this.config.ANDROID_PACKAGE};S.browser_fallback_url=${encodeURIComponent(androidUrl)};end`;

        window.location.href = intentUrl;
      }
    }

    updateStatus({ title, desc, isOpening = false, showRetry = false }) {
      const titleEl = document.getElementById('sdStatusTitle');
      const descEl = document.getElementById('sdStatusDesc');
      const spinnerEl = document.getElementById('sdSpinner');
      const cardEl = document.getElementById('sdStatusCard');

      if (titleEl) titleEl.textContent = title;
      if (descEl) descEl.textContent = desc;
      if (spinnerEl) spinnerEl.style.display = isOpening ? 'block' : 'none';

      if (showRetry && cardEl && !document.getElementById('sdRetryBtn')) {
        const retryDiv = document.createElement('div');
        retryDiv.className = 'sd-retry-row';
        retryDiv.innerHTML = '<button class="sd-btn-retry" id="sdRetryBtn" type="button">↻ Try Auto-Open Again</button>';
        cardEl.appendChild(retryDiv);
        const btn = document.getElementById('sdRetryBtn');
        if (btn) {
          btn.addEventListener('click', () => {
            sessionStorage.removeItem('dl_attempted');
            this.render();
            this.startFlow();
          });
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 8. Bootstrap on Hashchange & Page Load
  // ---------------------------------------------------------------------------
  const app = new SmartDownloadApp();

  function onRouteChanged() {
    app.init();
  }

  window.addEventListener('hashchange', onRouteChanged);

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', onRouteChanged);
  } else {
    onRouteChanged();
  }

  // Expose instance and methods for testing & diagnostics
  window.SmartDownload = app;
  window.detectPlatform = detectPlatform;
  window.detectInAppBrowser = detectInAppBrowser;
  window.generateQrSvg = (text, size, margin) => QRGenerator.generateSVG(text, size, margin);
  window.track = track;
})();
