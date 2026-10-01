#!/usr/bin/env node
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

async function decryptStrong(buf, pwd) {
    const header = Buffer.from("AUTHENTICATORPRO", "ascii");
    const headerLength = header.length;
    const saltLength = 16;
    const ivLength = 12;
    const tagLength = 16;

    if (buf.length <= headerLength + saltLength + ivLength + tagLength) {
        throw new Error("Encrypted file too short for strong format");
    }

    const salt = buf.slice(headerLength, headerLength + saltLength);
    const iv = buf.slice(
        headerLength + saltLength,
        headerLength + saltLength + ivLength,
    );
    const cipherPlusTag = buf.slice(headerLength + saltLength + ivLength);
    const authTag = cipherPlusTag.slice(cipherPlusTag.length - tagLength);
    const ciphertext = cipherPlusTag.slice(0, cipherPlusTag.length - tagLength);

    const argon2 = require("argon2");
    // Original C# params: Argon2id, Parallelism=4, Iterations=3, MemorySize=65536
    const key = await argon2.hash(pwd, {
        salt: salt,
        type: argon2.argon2id,
        timeCost: 3,
        memoryCost: 65536,
        parallelism: 4,
        hashLength: 32,
        raw: true,
    });
    const decipher = crypto.createDecipheriv("aes-256-gcm", key, iv);
    decipher.setAuthTag(authTag);
    const out1 = decipher.update(ciphertext);
    const out2 = decipher.final();
    return Buffer.concat([out1, out2]).toString("utf8");
}

function decryptLegacy(buf, pwd) {
    const header = Buffer.from("AuthenticatorPro", "ascii");
    const headerLength = header.length;
    const saltLength = 20;
    const ivLength = 16;

    if (buf.length <= headerLength + saltLength + ivLength) {
        throw new Error("Encrypted file too short for legacy format");
    }

    const salt = buf.slice(headerLength, headerLength + saltLength);
    const iv = buf.slice(
        headerLength + saltLength,
        headerLength + saltLength + ivLength,
    );
    const encrypted = buf.slice(headerLength + saltLength + ivLength);

    const key = crypto.pbkdf2Sync(
        Buffer.from(pwd, "utf8"),
        salt,
        64000,
        32,
        "sha1",
    );
    const decipher = crypto.createDecipheriv("aes-256-cbc", key, iv);
    const out1 = decipher.update(encrypted);
    const out2 = decipher.final();
    return Buffer.concat([out1, out2]).toString("utf8");
}

async function main() {
    const args = process.argv.slice(2);
    if (args.length < 2) {
        console.error(
            "Usage: node decrypt_backup.js <path-to-file> <password>",
        );
        process.exit(2);
    }

    const filePath = path.resolve(args[0]);
    const password = args[1];

    if (!fs.existsSync(filePath)) {
        console.error("File not found:", filePath);
        process.exit(2);
    }

    const buf = fs.readFileSync(filePath);

    // Try detect headers
    const strongHeader = Buffer.from("AUTHENTICATORPRO", "ascii");
    const legacyHeader = Buffer.from("AuthenticatorPro", "ascii");

    let decrypted = null;
    try {
        if (buf.slice(0, strongHeader.length).equals(strongHeader)) {
            try {
                decrypted = await decryptStrong(buf, password);
                console.log(
                    "Detected strong encrypted backup. Decryption successful.",
                );
            } catch (e) {
                console.warn(
                    "Strong decryption failed, trying legacy as fallback:",
                    e && e.message ? e.message : String(e),
                );
                // try legacy fallback
                decrypted = decryptLegacy(buf, password);
                console.log("Fallback legacy decryption succeeded.");
            }
        } else if (buf.slice(0, legacyHeader.length).equals(legacyHeader)) {
            decrypted = decryptLegacy(buf, password);
            console.log(
                "Detected legacy encrypted backup. Decryption successful.",
            );
        } else {
            // fallback: try both
            try {
                decrypted = await decryptStrong(buf, password);
                console.log("Fallback: strong decryption succeeded.");
            } catch (e) {
                decrypted = decryptLegacy(buf, password);
                console.log("Fallback: legacy decryption succeeded.");
            }
        }
    } catch (err) {
        console.error(
            "Decryption failed:",
            err && err.message ? err.message : String(err),
        );
        process.exit(1);
    }

    // Try to parse JSON
    try {
        const parsed = JSON.parse(decrypted);
        const outPath = filePath + ".decrypted.json";
        fs.writeFileSync(outPath, JSON.stringify(parsed, null, 2), "utf8");
        console.log("Parsed JSON and wrote to", outPath);
        // If it's a Stratum backup, summarize authenticators
        if (parsed && (parsed.authenticators || parsed.Authenticators)) {
            const auths = parsed.authenticators || parsed.Authenticators;
            console.log(
                `Found ${Array.isArray(auths) ? auths.length : 0} authenticators`,
            );
            if (Array.isArray(auths) && auths.length > 0) {
                console.log("Sample item:", auths[0]);
            }
        }
    } catch (err) {
        // not JSON; write raw
        const outPath = filePath + ".decrypted.txt";
        fs.writeFileSync(outPath, decrypted, "utf8");
        console.log("Decrypted content is not JSON, wrote text to", outPath);
    }
}

main().catch((e) => {
    console.error("Unhandled error:", e);
    process.exit(1);
});
