from micropython import const
from trezor import wire, ui
from trezor.utils import unimport, chunks


@unimport
async def layout_reset_device(session_id, msg):
    from trezor.messages.Success import Success
    from trezor.messages.FailureType import UnexpectedMessage
    from ..common.request_pin import request_pin_twice
    from ..common import storage

    if storage.is_initialized():
        raise wire.FailureError(UnexpectedMessage, 'Already initialized')

    mnemonic = await generate_mnemonic(
        session_id, msg.strength, msg.display_random)

    await show_mnemonic(mnemonic)

    if msg.pin_protection:
        pin = await request_pin_twice(session_id)
    else:
        pin = None

    storage.load_mnemonic(mnemonic)
    storage.load_settings(pin=pin,
                          passphrase_protection=msg.passphrase_protection,
                          language=msg.language,
                          label=msg.label)

    return Success(message='Initialized')


@unimport
async def generate_mnemonic(session_id, strength, display_random):
    from trezor.crypto import hashlib, random, bip39
    from trezor.messages.EntropyRequest import EntropyRequest
    from trezor.messages.FailureType import Other
    from trezor.messages.wire_types import EntropyAck

    if strength not in (128, 192, 256):
        raise wire.FailureError(
            Other, 'Invalid strength (has to be 128, 192 or 256 bits)')

    # if display_random:
    #     raise wire.FailureError(Other, 'Entropy display not implemented')

    ack = await wire.call(session_id, EntropyRequest(), EntropyAck)

    if len(ack.entropy) != 32:
        raise wire.FailureError(Other, 'Invalid entropy (has to be 32 bytes)')

    ctx = hashlib.sha256()
    ctx.update(random.bytes(32))
    ctx.update(ack.entropy)
    entropy = ctx.digest()

    return bip39.from_data(entropy[:strength // 8])


@unimport
async def show_mnemonic(mnemonic):
    from trezor.ui.scroll import paginate

    first_page = const(0)
    words_per_page = const(4)
    words = list(enumerate(mnemonic.split()))
    pages = list(chunks(words, words_per_page))
    await paginate(show_mnemonic_page, len(pages), first_page, pages)


async def show_mnemonic_page(page, page_count, mnemonic):
    from trezor.ui.button import Button, CONFIRM_BUTTON, CONFIRM_BUTTON_ACTIVE
    from trezor.ui.scroll import render_scrollbar, animate_swipe

    ui.display.clear()
    ui.header('Write down your seed', ui.ICON_RESET, ui.BLACK, ui.LIGHT_GREEN)
    render_scrollbar(page, page_count)

    for pi, (wi, word) in enumerate(mnemonic[page]):
        top = pi * 35 + 68
        pos = wi + 1
        offset = 0
        if pos > 9:
            offset += 12
        ui.display.text(
            10, top, '%d.' % pos, ui.BOLD, ui.LIGHT_GREEN, ui.BLACK)
        ui.display.text(
            30 + offset, top, '%s' % word, ui.BOLD, ui.WHITE, ui.BLACK)

    if page + 1 == page_count:
        await Button(
            (0, 240 - 48, 240, 48), 'Finish',
            normal_style=CONFIRM_BUTTON,
            active_style=CONFIRM_BUTTON_ACTIVE)
    else:
        await animate_swipe()