// Copyright (C) 2022 jmh
// SPDX-License-Identifier: GPL-3.0-only

import { Authenticator } from './entity/Authenticator';
import { AuthenticatorType } from './AuthenticatorType';
import { HashAlgorithm } from './generator/HashAlgorithm';
import { IconResolver } from './util/IconResolver';
import { SecretUtil } from './util/SecretUtil';

export interface UriParseResult {
  authenticator: Authenticator;
  pinLength: number;
}

interface VarintReadResult {
  value: number;
  offset: number;
}

interface MigrationAccount {
  secret: Uint8Array;
  username: string;
  issuer: string;
  algorithm: number;
  type: number;
  counter: number;
}

export class UriParser {
  public static parseOtpAuthMigrationUri(uri: string, iconResolver: IconResolver): Authenticator[] {
    const decodedUri = decodeURIComponent(uri.trim());
    const prefix = 'otpauth-migration://offline?data=';
    if (!decodedUri.startsWith(prefix)) {
      throw new Error('Invalid Google Authenticator migration URI');
    }

    const query = decodedUri.substring(prefix.length);
    const dataEnd = query.indexOf('&');
    const rawData = dataEnd >= 0 ? query.substring(0, dataEnd) : query;
    const payload = UriParser.base64ToBytes(rawData);
    const accounts = UriParser.parseMigrationPayload(payload);
    const authenticators: Authenticator[] = [];

    for (const account of accounts) {
      if (account.secret.length === 0) {
        continue;
      }

      const authenticator = new Authenticator();
      authenticator.secret = SecretUtil.bytesToBase32(account.secret);
      authenticator.username = account.username;
      authenticator.issuer = account.issuer || account.username;
      authenticator.type = account.type === 1 ? AuthenticatorType.Hotp : AuthenticatorType.Totp;
      authenticator.algorithm = UriParser.mapMigrationAlgorithm(account.algorithm);
      authenticator.digits = 6;
      authenticator.period = 30;
      authenticator.counter = Math.max(0, account.counter);
      authenticator.icon = IconResolver.findServiceKeyByName(authenticator.issuer);
      authenticators.push(authenticator);
    }

    return authenticators;
  }

  public static parseStandardUri(uri: string, iconResolver: IconResolver): UriParseResult {
    let protocol: string = '';
    let path: string = '';
    let search: string = '';

    const protocolIndex = uri.indexOf(':');
    if (protocolIndex !== -1) {
      protocol = uri.substring(0, protocolIndex);
      const rest = uri.substring(protocolIndex + 1);

      const searchIndex = rest.indexOf('?');
      if (searchIndex !== -1) {
        path = rest.substring(0, searchIndex);
        search = rest.substring(searchIndex + 1);
      } else {
        path = rest;
      }
    }

    let type: AuthenticatorType;
    switch (protocol) {
      case 'otpauth':
        if (path.startsWith('//totp')) {
          type = AuthenticatorType.Totp;
        } else if (path.startsWith('//hotp')) {
          type = AuthenticatorType.Hotp;
        } else if (path.startsWith('//yaotp')) {
          type = AuthenticatorType.YandexOtp;
        } else {
          throw new Error('Unsupported OTP type');
        }
        break;
      case 'motp':
        type = AuthenticatorType.MobileOtp;
        break;
      default:
        throw new Error('Unsupported URI scheme');
    }

    const authenticator = new Authenticator();
    authenticator.type = type;

    // 解析路径部分获取issuer和username
    const pathParts = path.split('/').filter(part => part !== '');
    if (pathParts.length > 1) {
      const issuerUsername = decodeURIComponent(pathParts[pathParts.length - 1]);
      const colonIndex = issuerUsername.indexOf(':');

      if (colonIndex !== -1) {
        authenticator.issuer = issuerUsername.substring(0, colonIndex).trim();
        authenticator.username = issuerUsername.substring(colonIndex + 1).trim();
      } else {
        authenticator.issuer = issuerUsername.trim();
      }
    }

    // 解析查询参数
    const params = UriParser.parseQueryString(search);

    const secret = params['secret'];
    if (!secret) {
      throw new Error('Missing secret parameter');
    }
    authenticator.secret = secret;

    const issuerParam = params['issuer'];
    if (issuerParam && !authenticator.issuer) {
      authenticator.issuer = decodeURIComponent(issuerParam).trim();
    }

    const algorithm = params['algorithm'];
    if (algorithm) {
      switch (algorithm.toUpperCase()) {
        case 'SHA1':
          authenticator.algorithm = HashAlgorithm.Sha1;
          break;
        case 'SHA256':
          authenticator.algorithm = HashAlgorithm.Sha256;
          break;
        case 'SHA512':
          authenticator.algorithm = HashAlgorithm.Sha512;
          break;
        default:
          throw new Error('Unsupported algorithm');
      }
    }

    const digits = params['digits'];
    if (digits) {
      authenticator.digits = parseInt(digits, 10);
    }

    const period = params['period'];
    if (period) {
      authenticator.period = parseInt(period, 10);
    }

    const counter = params['counter'];
    if (counter) {
      authenticator.counter = parseInt(counter, 10);
    }

    const pinLength = params['pin_length'];
    let pinLengthValue = 0;
    if (pinLength) {
      pinLengthValue = parseInt(pinLength, 10);
    }

    // 设置图标
    if (authenticator.issuer) {
      authenticator.icon = IconResolver.findServiceKeyByName(authenticator.issuer);
    }

    return {
      authenticator: authenticator,
      pinLength: pinLengthValue
    };
  }

  private static parseQueryString(query: string): Record<string, string> {
    const params: Record<string, string> = {};
    if (!query) {
      return params;
    }

    const pairs = query.split('&');
    for (const pair of pairs) {
      const parts = pair.split('=');
      const key = parts[0];
      const value = parts.length > 1 ? parts[1] : '';
      if (key) {
        params[key] = value ? decodeURIComponent(value) : '';
      }
    }

    return params;
  }

  private static mapMigrationAlgorithm(value: number): HashAlgorithm {
    switch (value) {
      case 2:
        return HashAlgorithm.Sha256;
      case 3:
        return HashAlgorithm.Sha512;
      case 1:
      default:
        return HashAlgorithm.Sha1;
    }
  }

  private static parseMigrationPayload(data: Uint8Array): MigrationAccount[] {
    const accounts: MigrationAccount[] = [];
    let offset = 0;

    while (offset < data.length) {
      const tag = UriParser.readVarint(data, offset);
      offset = tag.offset;
      const fieldNumber = Math.floor(tag.value / 8);
      const wireType = tag.value % 8;

      if (fieldNumber === 1 && wireType === 2) {
        const length = UriParser.readVarint(data, offset);
        offset = length.offset;
        const end = offset + length.value;
        accounts.push(UriParser.parseMigrationAccount(data.slice(offset, end)));
        offset = end;
      } else {
        offset = UriParser.skipProtoField(data, offset, wireType);
      }
    }

    return accounts;
  }

  private static parseMigrationAccount(data: Uint8Array): MigrationAccount {
    const account: MigrationAccount = {
      secret: new Uint8Array(),
      username: '',
      issuer: '',
      algorithm: 1,
      type: 2,
      counter: 0
    };
    let offset = 0;

    while (offset < data.length) {
      const tag = UriParser.readVarint(data, offset);
      offset = tag.offset;
      const fieldNumber = Math.floor(tag.value / 8);
      const wireType = tag.value % 8;

      if (wireType === 2) {
        const length = UriParser.readVarint(data, offset);
        offset = length.offset;
        const end = offset + length.value;
        const bytes = data.slice(offset, end);
        if (fieldNumber === 1) {
          account.secret = bytes;
        } else if (fieldNumber === 2) {
          account.username = UriParser.utf8ToString(bytes);
        } else if (fieldNumber === 3) {
          account.issuer = UriParser.utf8ToString(bytes);
        }
        offset = end;
      } else if (wireType === 0) {
        const value = UriParser.readVarint(data, offset);
        offset = value.offset;
        if (fieldNumber === 4) {
          account.algorithm = value.value;
        } else if (fieldNumber === 6) {
          account.type = value.value;
        } else if (fieldNumber === 7) {
          account.counter = value.value;
        }
      } else {
        offset = UriParser.skipProtoField(data, offset, wireType);
      }
    }

    return account;
  }

  private static readVarint(data: Uint8Array, offset: number): VarintReadResult {
    let value = 0;
    let multiplier = 1;
    let currentOffset = offset;

    while (currentOffset < data.length) {
      const byteValue = data[currentOffset++];
      value += (byteValue & 0x7F) * multiplier;
      if ((byteValue & 0x80) === 0) {
        return { value: value, offset: currentOffset };
      }
      multiplier *= 128;
    }

    throw new Error('Invalid protobuf varint');
  }

  private static skipProtoField(data: Uint8Array, offset: number, wireType: number): number {
    if (wireType === 0) {
      return UriParser.readVarint(data, offset).offset;
    }
    if (wireType === 1) {
      return offset + 8;
    }
    if (wireType === 2) {
      const length = UriParser.readVarint(data, offset);
      return length.offset + length.value;
    }
    if (wireType === 5) {
      return offset + 4;
    }
    throw new Error('Unsupported protobuf wire type');
  }

  private static base64ToBytes(value: string): Uint8Array {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    let normalized = value.replace(/-/g, '+').replace(/_/g, '/').replace(/\s/g, '');
    while (normalized.length % 4 !== 0) {
      normalized += '=';
    }

    const bytes: number[] = [];
    let buffer = 0;
    let bits = 0;
    for (let index = 0; index < normalized.length; index++) {
      const char = normalized.charAt(index);
      if (char === '=') {
        break;
      }
      const charValue = alphabet.indexOf(char);
      if (charValue < 0) {
        throw new Error('Invalid base64 data');
      }
      buffer = (buffer << 6) | charValue;
      bits += 6;
      if (bits >= 8) {
        bits -= 8;
        bytes.push((buffer >> bits) & 0xFF);
      }
    }

    return new Uint8Array(bytes);
  }

  private static utf8ToString(data: Uint8Array): string {
    let result = '';
    let index = 0;
    while (index < data.length) {
      const first = data[index];
      if (first < 0x80) {
        result += String.fromCharCode(first);
        index++;
      } else if ((first & 0xE0) === 0xC0 && index + 1 < data.length) {
        const second = data[index + 1];
        result += String.fromCharCode(((first & 0x1F) << 6) | (second & 0x3F));
        index += 2;
      } else if ((first & 0xF0) === 0xE0 && index + 2 < data.length) {
        const second = data[index + 1];
        const third = data[index + 2];
        result += String.fromCharCode(((first & 0x0F) << 12) | ((second & 0x3F) << 6) | (third & 0x3F));
        index += 3;
      } else if ((first & 0xF8) === 0xF0 && index + 3 < data.length) {
        const second = data[index + 1];
        const third = data[index + 2];
        const fourth = data[index + 3];
        const codePoint = ((first & 0x07) << 18) | ((second & 0x3F) << 12) | ((third & 0x3F) << 6) | (fourth & 0x3F);
        result += String.fromCharCode(0xD800 + ((codePoint - 0x10000) >> 10));
        result += String.fromCharCode(0xDC00 + ((codePoint - 0x10000) & 0x3FF));
        index += 4;
      } else {
        result += String.fromCharCode(first);
        index++;
      }
    }
    return result;
  }
}
