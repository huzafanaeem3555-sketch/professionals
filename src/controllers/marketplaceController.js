const MarketplaceModel = require('../models/marketplaceModel');

function uid(req) {
  return req.user?.uid || '';
}

const MarketplaceController = {
  async createComplaint(req, res) {
    try {
      const data = await MarketplaceModel.createComplaint(uid(req), req.body || {});
      return res.status(201).json({ success: true, data });
    } catch (error) {
      return res.status(400).json({ success: false, message: error.message });
    }
  },

  async listComplaints(req, res) {
    const data = await MarketplaceModel.listComplaints();
    return res.json({ success: true, data });
  },

  async updateComplaint(req, res) {
    const data = await MarketplaceModel.updateComplaint(req.params.id, req.body || {});
    return res.json({ success: true, data });
  },

  async deleteComplaint(req, res) {
    await MarketplaceModel.deleteComplaint(req.params.id);
    return res.json({ success: true });
  },

  async toggleFavorite(req, res) {
    try {
      const data = await MarketplaceModel.toggleFavorite(
        uid(req),
        req.params.professionalId || req.body?.professionalId,
        req.body?.favorite !== false,
      );
      return res.json({ success: true, data });
    } catch (error) {
      return res.status(400).json({ success: false, message: error.message });
    }
  },

  async listFavorites(req, res) {
    const data = await MarketplaceModel.listFavorites(uid(req));
    return res.json({ success: true, data });
  },

  async createReferral(req, res) {
    try {
      const data = await MarketplaceModel.createReferral(uid(req), req.body || {});
      return res.status(201).json({ success: true, data });
    } catch (error) {
      return res.status(400).json({ success: false, message: error.message });
    }
  },

  async applyReferral(req, res) {
    try {
      const data = await MarketplaceModel.applyReferral(uid(req), req.body?.code || req.params.code);
      return res.json({ success: true, data });
    } catch (error) {
      return res.status(400).json({ success: false, message: error.message });
    }
  },

  async listMyReferrals(req, res) {
    const data = await MarketplaceModel.listMyReferrals(uid(req));
    return res.json({ success: true, data });
  },

  async createJobPost(req, res) {
    try {
      const data = await MarketplaceModel.createJobPost(uid(req), req.body || {});
      return res.status(201).json({ success: true, data });
    } catch (error) {
      return res.status(400).json({ success: false, message: error.message });
    }
  },

  async listJobPosts(req, res) {
    const data = await MarketplaceModel.listJobPosts(req.user || {});
    return res.json({ success: true, data });
  },

  async createJobOffer(req, res) {
    try {
      const data = await MarketplaceModel.createJobOffer(uid(req), req.params.postId, req.body || {});
      return res.status(201).json({ success: true, data });
    } catch (error) {
      return res.status(400).json({ success: false, message: error.message });
    }
  },

  async listJobOffers(req, res) {
    const data = await MarketplaceModel.listJobOffers(req.params.postId);
    return res.json({ success: true, data });
  },

  async requestFeatured(req, res) {
    try {
      const data = await MarketplaceModel.requestFeatured(uid(req), req.body || {});
      return res.status(201).json({ success: true, data });
    } catch (error) {
      return res.status(400).json({ success: false, message: error.message });
    }
  },

  async uploadCertificate(req, res) {
    try {
      const data = await MarketplaceModel.uploadCertificate(uid(req), req.body || {});
      return res.status(201).json({ success: true, data });
    } catch (error) {
      return res.status(400).json({ success: false, message: error.message });
    }
  },

  async listCertificates(req, res) {
    const professionalId = req.params.professionalId || uid(req);
    const data = await MarketplaceModel.listCertificates(professionalId);
    return res.json({ success: true, data });
  },
};

module.exports = MarketplaceController;
