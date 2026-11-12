'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

// Execute the exact JavaScript shipped by the Objective-C callback, not a rewritten model.
const source = fs.readFileSync(path.join(__dirname, '../SlotMachineSuite/SlotMachineSuite/SMSWebViewController.m'), 'utf8');
const method = source.slice(source.indexOf('- (void)emitApplePayEvent:'));
const declaration = method.match(/NSString \*script\s*=([\s\S]*?);\n/);
assert.ok(declaration, 'native IAP event script exists');
const script = [...declaration[1].matchAll(/@?"(?:\\.|[^"\\])*"/g)]
    .map(match => JSON.parse(match[0].replace(/^@/, ''))).join('');

function run(overrides = {}) {
    const received = [];
    const window = {
        __smsWebDocumentID: 'document-a',
        __smsApplePayScope: 'session-a',
        dispatchEvent: event => received.push(['dom', event.type, event.detail]),
        cc: { director: { emit: (name, event) => received.push(['cocos', name, event]) } },
        ...overrides.window,
    };
    const event = { status: 'verified', verified: true, orderNo: 'order-a' };
    vm.runInNewContext(script, {
        location: { protocol: 'https:', hostname: 'game.example.com', ...overrides.location },
        hosts: ['game.example.com'], documentID: 'document-a', scope: 'session-a', event,
        window, CustomEvent: function (type, options) { this.type = type; this.detail = options.detail; },
    });
    return received;
}
const delivered = run();
assert.equal(delivered.length, 2, 'deliver DOM and Cocos events to the requesting document');
assert.deepEqual(delivered.map(item => item.slice(0, 2)), [
    ['dom', 'ON_APPLEPAY_STATUS'], ['cocos', 'ON_APPLEPAY_STATUS'],
]);
assert.equal(delivered[0][2].status, 'verified');
assert.equal(run({ window: { __smsWebDocumentID: 'new-document' } }).length, 0, 'drop events after navigation');
assert.equal(run({ window: { __smsApplePayScope: 'new-account-session' } }).length, 0, 'drop queued events after account switch');
assert.equal(run({ window: { __smsApplePayScope: '' } }).length, 0, 'drop queued events after logout');
assert.equal(run({ location: { hostname: 'untrusted.example.com' } }).length, 0, 'reject an untrusted host');
assert.equal(run({ location: { protocol: 'http:' } }).length, 0, 'require HTTPS');
assert.equal(run({ window: { cc: undefined } }).length, 1, 'plain H5 does not require Cocos');
const installLiteral = source.match(/@"if\(window\.__smsWebDocumentID!==documentID\)[^\n]+?"/);
assert.ok(installLiteral, 'scope installation checks document identity');
const install = JSON.parse(installLiteral[0].slice(1));
const replacement = { __smsWebDocumentID: 'new-document', __smsApplePayScope: 'new-session' };
assert.equal(vm.runInNewContext(`(function(){${install}})()`, {
    window: replacement, documentID: 'old-document', scope: 'old-session',
}), false);
assert.equal(replacement.__smsApplePayScope, 'new-session', 'old configuration cannot mutate a new document');
const clearLiteral = source.match(/@"if\(window\.__smsApplePayScope===scope\)[^\n]+?"/);
assert.ok(clearLiteral, 'logout invalidation checks the old scope');
vm.runInNewContext(JSON.parse(clearLiteral[0].slice(1)), { window: replacement, scope: 'old-session' });
assert.equal(replacement.__smsApplePayScope, 'new-session', 'late logout cannot clear a newer session');
console.log('PASS: Apple Pay DOM/Cocos callback, document/session isolation and origin checks');
