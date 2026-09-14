import Array "mo:base/Array";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Buffer "mo:base/Buffer";

actor MarketplaceArFa {

    // ==========================================
    // TIPE DATA DAN ENUM
    // ==========================================

    /// Status pesanan dalam marketplace
    type StatusPesanan = {
        #MenungguPembayaran;
        #Dibayar;
        #MenungguPengiriman;
        #Selesai;
        #Dibatalkan;
    };

    /// Detail produk di marketplace
    type Produk = {
        id : Nat;
        nama : Text;
        deskripsi : Text;
        harga : Nat;
        stok : Nat;
        penjual : Principal;
        dibuat : Int;
        diperbarui : Int;
    };

    /// Detail pesanan
    type Pesanan = {
        idPesanan : Nat;
        idProduk : Nat;
        namaProduk : Text;
        pembeli : Principal;
        penjual : Principal;
        jumlah : Nat;
        totalHarga : Nat;
        status : StatusPesanan;
        dibuat : Int;
        diperbarui : Int;
    };

    /// Response type untuk operasi
    type Result<T, E> = Result.Result<T, E>;
    
    type Error = {
        #ProdukTidakDitemukan;
        #StokTidakCukup;
        #PesananTidakDitemukan;
        #TidakBerhak;
        #StatusTidakValid;
        #InputTidakValid;
        #PenjualTidakBisaMembeli;
    };

    // ==========================================
    // PENYIMPANAN DATA (STABLE)
    // ==========================================

    private stable var daftarProduk : [Produk] = [];
    private stable var daftarPesanan : [Pesanan] = [];

    private stable var idProdukCounter : Nat = 1;
    private stable var idPesananCounter : Nat = 1;

    // ==========================================
    // HELPER FUNCTIONS
    // ==========================================

    /// Validasi input teks
    private func isValidText(text : Text) : Bool {
        text.size() > 0 and text.size() <= 500
    };

    /// Validasi harga
    private func isValidPrice(price : Nat) : Bool {
        price > 0
    };

    /// Validasi stok
    private func isValidStock(stock : Nat) : Bool {
        stock > 0
    };

    /// Cari produk berdasarkan ID
    private func findProduk(id : Nat) : ?Produk {
        Array.find<Produk>(
            daftarProduk,
            func(produk) { produk.id == id }
        )
    };

    /// Cari pesanan berdasarkan ID
    private func findPesanan(id : Nat) : ?Pesanan {
        Array.find<Pesanan>(
            daftarPesanan,
            func(pesanan) { pesanan.idPesanan == id }
        )
    };

    // ==========================================
    // MANAJEMEN PRODUK
    // ==========================================

    /// Tambah produk baru ke marketplace
    public shared (msg) func tambahProduk(
        nama : Text,
        deskripsi : Text,
        harga : Nat,
        stok : Nat
    ) : async Result<Nat, Error> {

        // Validasi input
        if (not isValidText(nama)) {
            return #err(#InputTidakValid);
        };
        if (not isValidText(deskripsi)) {
            return #err(#InputTidakValid);
        };
        if (not isValidPrice(harga)) {
            return #err(#InputTidakValid);
        };
        if (not isValidStock(stok)) {
            return #err(#InputTidakValid);
        };

        let sekarang = Time.now();
        let produkBaru : Produk = {
            id = idProdukCounter;
            nama = nama;
            deskripsi = deskripsi;
            harga = harga;
            stok = stok;
            penjual = msg.caller;
            dibuat = sekarang;
            diperbarui = sekarang;
        };

        daftarProduk := Array.append(daftarProduk, [produkBaru]);

        let idBaru = idProdukCounter;
        idProdukCounter += 1;

        #ok(idBaru)
    };

    /// Lihat semua produk
    public query func lihatSemuaProduk() : async [Produk] {
        daftarProduk
    };

    /// Lihat produk spesifik
    public query func lihatProduk(idProduk : Nat) : async Result<?Produk, Error> {
        switch (findProduk(idProduk)) {
            case (null) { #err(#ProdukTidakDitemukan) };
            case (?produk) { #ok(?produk) };
        }
    };

    /// Perbarui produk (hanya penjual)
    public shared (msg) func perbaruiProduk(
        idProduk : Nat,
        nama : Text,
        deskripsi : Text,
        harga : Nat,
        stok : Nat
    ) : async Result<(), Error> {

        let produkOpt = findProduk(idProduk);

        switch (produkOpt) {
            case (null) { return #err(#ProdukTidakDitemukan) };
            case (?produk) {
                if (produk.penjual != msg.caller) {
                    return #err(#TidakBerhak);
                };

                if (not isValidText(nama) or not isValidText(deskripsi) or not isValidPrice(harga) or not isValidStock(stok)) {
                    return #err(#InputTidakValid);
                };

                let produkDiperbarui : Produk = {
                    id = produk.id;
                    nama = nama;
                    deskripsi = deskripsi;
                    harga = harga;
                    stok = stok;
                    penjual = produk.penjual;
                    dibuat = produk.dibuat;
                    diperbarui = Time.now();
                };

                daftarProduk := Array.map<Produk, Produk>(
                    daftarProduk,
                    func(item) {
                        if (item.id == idProduk) { produkDiperbarui } else { item }
                    }
                );

                #ok()
            };
        }
    };

    // ==========================================
    // MANAJEMEN PESANAN
    // ==========================================

    /// Buat pesanan baru
    public shared (msg) func buatPesanan(
        idProduk : Nat,
        jumlah : Nat
    ) : async Result<Nat, Error> {

        if (jumlah == 0) {
            return #err(#InputTidakValid);
        };

        let produkOpt = findProduk(idProduk);

        switch (produkOpt) {
            case (null) {
                return #err(#ProdukTidakDitemukan);
            };

            case (?produk) {
                // Validasi: Penjual tidak bisa membeli produknya sendiri
                if (produk.penjual == msg.caller) {
                    return #err(#PenjualTidakBisaMembeli);
                };

                // Validasi: Stok mencukupi
                if (produk.stok < jumlah) {
                    return #err(#StokTidakCukup);
                };

                let totalHarga = produk.harga * jumlah;
                let sekarang = Time.now();

                let pesananBaru : Pesanan = {
                    idPesanan = idPesananCounter;
                    idProduk = produk.id;
                    namaProduk = produk.nama;
                    pembeli = msg.caller;
                    penjual = produk.penjual;
                    jumlah = jumlah;
                    totalHarga = totalHarga;
                    status = #MenungguPembayaran;
                    dibuat = sekarang;
                    diperbarui = sekarang;
                };

                daftarPesanan := Array.append(daftarPesanan, [pesananBaru]);

                // Kurangi stok produk
                daftarProduk := Array.map<Produk, Produk>(
                    daftarProduk,
                    func(item) {
                        if (item.id == idProduk) {
                            {
                                id = item.id;
                                nama = item.nama;
                                deskripsi = item.deskripsi;
                                harga = item.harga;
                                stok = item.stok - jumlah;
                                penjual = item.penjual;
                                dibuat = item.dibuat;
                                diperbarui = Time.now();
                            }
                        } else {
                            item
                        }
                    }
                );

                let idBaru = idPesananCounter;
                idPesananCounter += 1;

                #ok(idBaru)
            };
        }
    };

    /// Lihat pesanan spesifik
    public query func lihatPesanan(idPesanan : Nat) : async Result<?Pesanan, Error> {
        switch (findPesanan(idPesanan)) {
            case (null) { #err(#PesananTidakDitemukan) };
            case (?pesanan) { #ok(?pesanan) };
        }
    };

    /// Lihat semua pesanan user (sebagai pembeli atau penjual)
    public query func lihatSemuaPesananSaya(user : Principal) : async [Pesanan] {
        Array.filter<Pesanan>(
            daftarPesanan,
            func(pesanan) {
                pesanan.pembeli == user or pesanan.penjual == user
            }
        )
    };

    // ==========================================
    // PERUBAHAN STATUS PESANAN
    // ==========================================

    /// Pembatalkan pesanan (hanya pembeli)
    public shared (msg) func batalkanPesanan(idPesanan : Nat) : async Result<(), Error> {

        let pesananOpt = findPesanan(idPesanan);

        switch (pesananOpt) {
            case (null) {
                return #err(#PesananTidakDitemukan);
            };

            case (?pesanan) {
                // Hanya pembeli yang bisa membatalkan
                if (pesanan.pembeli != msg.caller) {
                    return #err(#TidakBerhak);
                };

                // Hanya bisa dibatalkan saat menunggu pembayaran
                if (pesanan.status != #MenungguPembayaran) {
                    return #err(#StatusTidakValid);
                };

                // Update status pesanan
                daftarPesanan := Array.map<Pesanan, Pesanan>(
                    daftarPesanan,
                    func(item) {
                        if (item.idPesanan == idPesanan) {
                            {
                                idPesanan = item.idPesanan;
                                idProduk = item.idProduk;
                                namaProduk = item.namaProduk;
                                pembeli = item.pembeli;
                                penjual = item.penjual;
                                jumlah = item.jumlah;
                                totalHarga = item.totalHarga;
                                status = #Dibatalkan;
                                dibuat = item.dibuat;
                                diperbarui = Time.now();
                            }
                        } else {
                            item
                        }
                    }
                );

                // Kembalikan stok produk
                daftarProduk := Array.map<Produk, Produk>(
                    daftarProduk,
                    func(item) {
                        if (item.id == pesanan.idProduk) {
                            {
                                id = item.id;
                                nama = item.nama;
                                deskripsi = item.deskripsi;
                                harga = item.harga;
                                stok = item.stok + pesanan.jumlah;
                                penjual = item.penjual;
                                dibuat = item.dibuat;
                                diperbarui = Time.now();
                            }
                        } else {
                            item
                        }
                    }
                );

                #ok()
            };
        }
    };

    /// Konfirmasi pembayaran (hanya penjual)
    public shared (msg) func konfirmasiPembayaran(idPesanan : Nat) : async Result<(), Error> {

        let pesananOpt = findPesanan(idPesanan);

        switch (pesananOpt) {
            case (null) {
                return #err(#PesananTidakDitemukan);
            };

            case (?pesanan) {
                // Hanya penjual yang bisa konfirmasi pembayaran
                if (pesanan.penjual != msg.caller) {
                    return #err(#TidakBerhak);
                };

                if (pesanan.status != #MenungguPembayaran) {
                    return #err(#StatusTidakValid);
                };

                daftarPesanan := Array.map<Pesanan, Pesanan>(
                    daftarPesanan,
                    func(item) {
                        if (item.idPesanan == idPesanan) {
                            {
                                idPesanan = item.idPesanan;
                                idProduk = item.idProduk;
                                namaProduk = item.namaProduk;
                                pembeli = item.pembeli;
                                penjual = item.penjual;
                                jumlah = item.jumlah;
                                totalHarga = item.totalHarga;
                                status = #Dibayar;
                                dibuat = item.dibuat;
                                diperbarui = Time.now();
                            }
                        } else {
                            item
                        }
                    }
                );

                #ok()
            };
        }
    };

    /// Konfirmasi pengiriman (hanya penjual)
    public shared (msg) func konfirmasiPengiriman(idPesanan : Nat) : async Result<(), Error> {

        let pesananOpt = findPesanan(idPesanan);

        switch (pesananOpt) {
            case (null) {
                return #err(#PesananTidakDitemukan);
            };

            case (?pesanan) {
                // Hanya penjual yang bisa konfirmasi pengiriman
                if (pesanan.penjual != msg.caller) {
                    return #err(#TidakBerhak);
                };

                if (pesanan.status != #Dibayar) {
                    return #err(#StatusTidakValid);
                };

                daftarPesanan := Array.map<Pesanan, Pesanan>(
                    daftarPesanan,
                    func(item) {
                        if (item.idPesanan == idPesanan) {
                            {
                                idPesanan = item.idPesanan;
                                idProduk = item.idProduk;
                                namaProduk = item.namaProduk;
                                pembeli = item.pembeli;
                                penjual = item.penjual;
                                jumlah = item.jumlah;
                                totalHarga = item.totalHarga;
                                status = #MenungguPengiriman;
                                dibuat = item.dibuat;
                                diperbarui = Time.now();
                            }
                        } else {
                            item
                        }
                    }
                );

                #ok()
            };
        }
    };

    /// Konfirmasi penerimaan barang (hanya pembeli)
    public shared (msg) func konfirmasiPenerimaan(idPesanan : Nat) : async Result<(), Error> {

        let pesananOpt = findPesanan(idPesanan);

        switch (pesananOpt) {
            case (null) {
                return #err(#PesananTidakDitemukan);
            };

            case (?pesanan) {
                // Hanya pembeli yang bisa konfirmasi penerimaan
                if (pesanan.pembeli != msg.caller) {
                    return #err(#TidakBerhak);
                };

                if (pesanan.status != #MenungguPengiriman) {
                    return #err(#StatusTidakValid);
                };

                daftarPesanan := Array.map<Pesanan, Pesanan>(
                    daftarPesanan,
                    func(item) {
                        if (item.idPesanan == idPesanan) {
                            {
                                idPesanan = item.idPesanan;
                                idProduk = item.idProduk;
                                namaProduk = item.namaProduk;
                                pembeli = item.pembeli;
                                penjual = item.penjual;
                                jumlah = item.jumlah;
                                totalHarga = item.totalHarga;
                                status = #Selesai;
                                dibuat = item.dibuat;
                                diperbarui = Time.now();
                            }
                        } else {
                            item
                        }
                    }
                );

                #ok()
            };
        }
    };

}
