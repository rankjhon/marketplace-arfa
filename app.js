// Inisialisasi Pi SDK (Sandbox mode untuk Testnet)
const Pi = window.Pi;
Pi.init({ version: "2.0", sandbox: true });

// 1. Authenticate Pengguna via Pi Browser
async function loginPi() {
    try {
        const scopes = ['username', 'payments'];
        const auth = await Pi.authenticate(scopes, onIncompletePaymentFound);
        document.getElementById('status').innerText = "Terhubung sebagai: " + auth.user.username;
    } catch (err) {
        console.error("Gagal verifikasi Pi:", err);
    }
}

// 2. Fungsi Pembayaran Pi (Memanggil Pembayaran & Canister ICP)
async function bayarDenganPi(idProduk, hargaPi) {
    const paymentData = {
        amount: hargaPi,
        memo: "Pembelian Produk ID: " + idProduk,
        metadata: { idProduk: idProduk }
    };

    const paymentCallbacks = {
        onReadyForServerApproval: function(paymentId) {
            console.log("Menunggu persetujuan server/canister...", paymentId);
            // Panggil Canister ICP untuk mengeksekusi buatPesanan()
        },
        onReadyForServerCompletion: function(paymentId, txid) {
            console.log("Pembayaran selesai di Pi Network!", txid);
            // Panggil Canister ICP untuk konfirmasiPembayaran()
        },
        onCancel: function(paymentId) { console.log("Pembayaran dibatalkan"); },
        onError: function(error, payment) { console.error("Error pembayaran:", error); }
    };

    Pi.createPayment(paymentData, paymentCallbacks);
}

function onIncompletePaymentFound(payment) {
    console.log("Ditemukan pembayaran yang belum selesai:", payment);
}
